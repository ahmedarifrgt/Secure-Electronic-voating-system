"""Face verification orchestration.

Runs the full multi-stage face authentication pipeline in order:

1. Image quality validation
2. Face tracking (exactly one face)
3. Liveness detection
4. Anti-spoof detection
5. Deepfake detection
6. DeepFace (or stored-embedding) identity verification

Each stage is logged to `face_logs`. Returns a detailed dict.
"""
import os

from backend.config import Config
from backend.services.authentication.image_quality import validate_image_quality
from backend.services.authentication.face_tracking import check_face_tracking
from backend.services.authentication.liveness_detection import check_liveness
from backend.services.authentication.anti_spoofing import check_anti_spoofing
from backend.services.authentication.deepfake_detection import check_deepfake
from backend.services.authentication.face_embedding import (
    generate_embedding,
    compare_embeddings,
    embedding_to_bytes,
)
from backend.services.authentication.verification_logger import (
    log_face_stage,
    log_security_event,
)

HAS_DEEPFACE = False
try:
    from deepface import DeepFace  # type: ignore
    HAS_DEEPFACE = True
except Exception:
    HAS_DEEPFACE = False


def _mock_allowed() -> bool:
    return Config.MOCK_FACE_VERIFICATION or os.getenv("MOCK_FACE_VERIFICATION", "").lower() in ("1", "true", "yes")


def verify_face_pipeline(registered_image, live_image, voter_id=None, nid=None,
                         stored_embedding=None, live_capture=False,
                         extra_frames=None, ip_address=None) -> dict:
    """Run the full authentication pipeline.

    Returns a dict with `passed`, `score`, `details`, `logs`.
    """
    if _mock_allowed():
        return {
            "passed": True,
            "score": 1.0,
            "details": {"mode": "mock"},
            "logs": [],
            "error": None,
        }

    pipeline = []

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

    # 6. Identity verification (DeepFace or stored embedding)
    verified = False
    distance = None
    confidence = 0.0
    try:
        if HAS_DEEPFACE:
            res = DeepFace.verify(
                img1_path=registered_image,
                img2_path=live_image,
                model_name=Config.DEEPFACE_MODEL,
                detector_backend=Config.DEEPFACE_DETECTOR,
                enforce_detection=True,
            )
            if isinstance(res, dict):
                distance = res.get("distance")
                verified = bool(res.get("verified"))
            if distance is not None and isinstance(distance, (int, float)):
                verified = verified and (distance <= Config.FACE_THRESHOLD)
                # Convert distance to a 0..1 confidence score
                confidence = max(0.0, min(1.0, 1.0 - (distance / 1.5)))
        elif stored_embedding:
            # Use stored embedding comparison fallback
            live_emb = generate_embedding(live_image, Config.DEEPFACE_MODEL)
            sim = compare_embeddings(stored_embedding, live_emb)
            confidence = sim
            verified = sim >= Config.FACE_THRESHOLD
        else:
            return _fail(pipeline, "No verification backend available")
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

