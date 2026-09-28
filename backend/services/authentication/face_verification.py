"""Face verification orchestration.

Runs the full multi-stage face authentication pipeline in order:

1. Image quality validation
2. Face tracking (exactly one face)
3. Liveness detection
4. Anti-spoof detection
5. Deepfake detection
6. DeepFace identity verification

Each stage is logged to `face_logs`. Returns a detailed dict.
"""
import os
from pathlib import Path

DEEPFACE_HOME = Path(os.getenv(
    "DEEPFACE_HOME",
    str(Path(__file__).resolve().parents[2] / "tmp" / "deepface"),
))
DEEPFACE_HOME.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("DEEPFACE_HOME", str(DEEPFACE_HOME))

from backend.config import Config
from backend.services.authentication.face_embedding import (
    EMBEDDING_DIM,
    compare_embeddings,
    generate_embedding,
    normalize_distance_metric,
)
from backend.services.authentication.face_tracking import detect_faces
from backend.services.authentication.image_quality import validate_image_quality
from backend.services.authentication.face_tracking import check_face_tracking
from backend.services.authentication.liveness_detection import check_liveness
from backend.services.authentication.anti_spoofing import check_anti_spoofing
from backend.services.authentication.deepfake_detection import check_deepfake
from backend.services.authentication.verification_logger import (
    log_face_stage,
    log_security_event,
)

# DeepFace is accessed via a non-blocking loader so an incompatible install
# can never hang the backend at import time or during a request.
from backend.services.authentication._deepface_loader import (
    deepface as _deepface,
    _SENTINEL,
)

HAS_DEEPFACE = False


def deepface_available() -> bool:
    """Whether DeepFace can actually be imported (cached, non-blocking)."""
    return _deepface() is not _SENTINEL


def verify_face_pipeline(registered_image, live_image, voter_id=None, nid=None,
                         stored_embedding=None, live_capture=False,
                         extra_frames=None, ip_address=None) -> dict:
    """Run the full authentication pipeline.

    Returns a dict with `passed`, `score`, `details`, `logs`.
    """
    pipeline = []

    if not registered_image:
        return _fail(pipeline, "Registered face image is missing")
    if not deepface_available():
        return _fail(pipeline, "DeepFace is required for face verification")

    try:
        registered_faces = detect_faces(registered_image)
        live_faces = detect_faces(live_image)
    except Exception as exc:
        pipeline.append(("face_detection", False, {"error": str(exc)}))
        log_face_stage(
            voter_id, nid, "face_detection", "Failed", details={"error": str(exc)}
        )
        return _fail(pipeline, f"Face detection failed: {exc}")

    if len(registered_faces) != 1:
        details = {"registered_faces": len(registered_faces), "live_faces": len(live_faces)}
        pipeline.append(("face_detection", False, details))
        log_face_stage(voter_id, nid, "face_detection", "Failed", details=details)
        return _fail(pipeline, "Registered image must contain exactly one face")
    if len(live_faces) != 1:
        details = {"registered_faces": len(registered_faces), "live_faces": len(live_faces)}
        pipeline.append(("face_detection", False, details))
        log_face_stage(voter_id, nid, "face_detection", "Failed", details=details)
        return _fail(pipeline, "Live image must contain exactly one face")

    face_details = {"registered_faces": 1, "live_faces": 1}
    pipeline.append(("face_detection", True, face_details))
    log_face_stage(voter_id, nid, "face_detection", "Success", details=face_details)

    # 1. Image quality
    q = validate_image_quality(live_image)
    pipeline.append(("image_quality", q["passed"], q["details"]))
    log_face_stage(voter_id, nid, "image_quality", "Success" if q["passed"] else "Failed", details=q["details"])
    if not q["passed"]:
        log_security_event("PoorImageQuality", "Warning", ip_address, q["reasons"])
        return _fail(pipeline, "Image quality validation failed")

    # 2. Face tracking
    ft = check_face_tracking(live_image)
    pipeline.append(("face_tracking", ft["passed"], ft.get("details", {})))
    log_face_stage(voter_id, nid, "face_tracking", "Success" if ft["passed"] else "Failed", details=ft)
    if not ft["passed"]:
        log_security_event("FaceTrackingFailed", "Warning", ip_address, ft)
        return _fail(pipeline, "Face tracking check failed")

    # 3. Liveness detection
    frames = [live_image] + (extra_frames or [])
    lv = check_liveness(frames, live_capture=live_capture)
    pipeline.append(("liveness", lv["passed"], lv.get("details", {})))
    log_face_stage(voter_id, nid, "liveness", "Success" if lv["passed"] else "Failed", details=lv)
    if not lv["passed"]:
        log_security_event("LivenessFailed", "Critical", ip_address, lv)
        return _fail(pipeline, "Liveness detection failed")

    # 4. Anti-spoofing
    sp = check_anti_spoofing(live_image)
    pipeline.append(("anti_spoof", sp["passed"], sp.get("details", {})))
    log_face_stage(voter_id, nid, "anti_spoof", "Success" if sp["passed"] else "Failed", details=sp)
    if not sp["passed"]:
        log_security_event("SpoofDetected", "Critical", ip_address, sp)
        return _fail(pipeline, "Anti-spoof check failed")

    # 5. Deepfake detection
    df = check_deepfake(live_image)
    pipeline.append(("deepfake", df["passed"], df.get("details", {})))
    log_face_stage(voter_id, nid, "deepfake", "Success" if df["passed"] else "Failed", details=df)
    if not df["passed"]:
        log_security_event("DeepfakeDetected", "Critical", ip_address, df)
        return _fail(pipeline, "Deepfake detection flagged the image")

# 6. Identity verification (strict DeepFace 1:1 match)
    verified = False
    distance = None
    confidence = 0.0
    try:
        timeout_seconds = float(getattr(Config, "DEEPFACE_TIMEOUT_SECONDS", 20.0))
        distance_metric = normalize_distance_metric(Config.DEEPFACE_DISTANCE_METRIC)
        threshold = float(Config.FACE_THRESHOLD)

        if stored_embedding is not None:
            registered_embedding = _validate_stored_embedding(stored_embedding)
        else:
            detector = _resolve_working_detector(registered_image, timeout_seconds)
            if detector is None:
                raise RuntimeError(
                    "No working face detector available for DeepFace identity "
                    f"verification. Tried: {getattr(Config, 'DEEPFACE_DETECTORS', ['mtcnn'])}"
                )
            registered_embedding = generate_embedding(
                registered_image,
                model_name=Config.DEEPFACE_MODEL,
                detector_backend=detector,
                strict=True,
            )

        # Registration uses this configured detector, so use the same backend
        # for the live image. No alternate detector probe is needed when the
        # stored embedding is already available.
        detector = getattr(Config, "DEEPFACE_DETECTOR", "mtcnn")

        live_embedding = generate_embedding(
            live_image,
            model_name=Config.DEEPFACE_MODEL,
            detector_backend=detector,
            strict=True,
        )

        distance = compare_embeddings(
            registered_embedding,
            live_embedding,
            distance_metric,
        )
        verified = distance <= threshold
        confidence = max(0.0, min(1.0, 1.0 - (distance / max(threshold, 1e-6))))
    except Exception as e:
        return _fail(pipeline, f"Identity verification error: {e}")

    pipeline.append(("identity", verified, {"distance": distance, "confidence": confidence}))
    log_face_stage(voter_id, nid, "identity", "Success" if verified else "Failed",
                   confidence=confidence, details={"distance": distance})
    if not verified:
        log_security_event("FaceVerificationFailed", "Warning", ip_address,
                           {"nid": nid, "distance": distance})
        return _fail(pipeline, "Face verification failed")

    return {
        "passed": True,
        "score": confidence,
        "details": {"pipeline": pipeline},
        "logs": [],
        "error": None,
    }


def _resolve_working_detector(image_path: str, timeout_seconds: float = 20.0):
    """Return the first configured detector that produces a real embedding.

    The configured default detector may be broken in a given environment (e.g.
    'opencv' without haarcascade data). We probe each candidate detector against
    the registered image and return the first that yields a genuine DeepFace
    identity embedding. If none works, return None so the caller fails closed —
    the pipeline must never accept a face via a weak, non-identity descriptor.
    """
    candidates = list(getattr(Config, "DEEPFACE_DETECTORS", [Config.DEEPFACE_DETECTOR]))
    if not candidates:
        candidates = [Config.DEEPFACE_DETECTOR]

    for detector in candidates:
        try:
            emb = generate_embedding(
                image_path,
                model_name=Config.DEEPFACE_MODEL,
                detector_backend=detector,
                strict=True,
            )
            if emb is not None and hasattr(emb, "size") and emb.size == 512:
                return detector
        except Exception:
            # Try the next detector; a broken detector must not be trusted.
            continue
    return None


def _validate_stored_embedding(embedding):
    """Accept only a valid stored DeepFace embedding; otherwise fail closed."""
    import numpy as np

    vector = np.asarray(embedding, dtype=np.float32)
    if vector.size != EMBEDDING_DIM or not np.all(np.isfinite(vector)):
        raise ValueError(
            f"Stored face embedding must contain {EMBEDDING_DIM} finite values"
        )
    norm = np.linalg.norm(vector)
    if norm == 0:
        raise ValueError("Stored face embedding is empty")
    return vector / norm


def _fail(pipeline, reason):
    return {
        "passed": False,
        "score": 0.0,
        "details": {"pipeline": pipeline},
        "logs": [],
        "error": reason,
    }


def verify_face(registered_image, live_image, **kwargs) -> bool:
    """Compatibility wrapper returning a boolean."""
    info = verify_face_pipeline(registered_image, live_image, **kwargs)
    return bool(info.get("passed"))
