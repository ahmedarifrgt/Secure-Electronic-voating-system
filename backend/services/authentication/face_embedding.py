"""Face embedding generation."""
import os
import threading

from backend.config import Config

# Non-blocking DeepFace access. The installed deepface stack can deadlock the
# process under `from deepface import DeepFace`, so we never import it at
# module scope — use `_deepface()` to obtain the module lazily.
from backend.services.authentication._deepface_loader import (
    deepface as _load_deepface,
    _SENTINEL,
)


def has_deepface() -> bool:
    """Return whether DeepFace is importable (checked lazily, non-blocking)."""
    return _load_deepface() is not _SENTINEL


def _deepface():
    """Return the DeepFace module or a sentinel if unavailable."""
    return _load_deepface()

# Backward-compatible name; computed lazily so module import never blocks.
HAS_DEEPFACE = False

HAS_CV2 = False
try:
    import cv2
    HAS_CV2 = True
except Exception:
    HAS_CV2 = False

import numpy as np

EMBEDDING_DIM = 512
SUPPORTED_DISTANCE_METRICS = {"cosine", "euclidean", "euclidean_l2"}


def _load_image(image_path: str):
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found: {image_path}")
    if not HAS_CV2:
        return None
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Unable to read image: {image_path}")
    return cv2.cvtColor(img, cv2.COLOR_BGR2RGB)


def run_with_timeout(func, timeout_seconds: float = 2.5, default=None):
    """Run a callable in a worker thread and return ``default`` on timeout."""
    result_container = {}
    error_container = {}

    def _worker():
        try:
            result_container["value"] = func()
        except Exception as exc:  # pragma: no cover - exercised in tests
            error_container["value"] = exc

    thread = threading.Thread(target=_worker, daemon=True)
    thread.start()
    thread.join(timeout_seconds)

    if thread.is_alive():
        return default

    if "value" in result_container:
        return result_container["value"]
    if "value" in error_container:
        raise error_container["value"]
    return default


def generate_embedding(image_path: str, model_name: str = "ArcFace",
                       detector_backend: str = "mtcnn",
                       strict: bool = True) -> np.ndarray:
    """Return a 512-dim normalized embedding for the given image path.

    For real voter verification, ``strict=True`` is required. A real DeepFace
    identity embedding is mandatory; if DeepFace is unavailable or the detector
    fails, this raises instead of silently falling back to the non-identity
    OpenCV descriptor — so a broken identity backend can never cause a false
    acceptance. The weak OpenCV descriptor is only produced when ``strict=False``
    (explicitly, e.g. for pipeline smoke-testing).
    """
    DeepFace = _deepface()
    if DeepFace is not _SENTINEL:
        try:
            # TensorFlow/Keras is not thread-safe during model initialization or
            # inference on Windows. Running this in a worker can return a false
            # timeout even when the same call succeeds on the main thread.
            emb = DeepFace.represent(
                img_path=image_path,
                model_name=model_name,
                detector_backend=detector_backend,
                enforce_detection=True,
            )
            if isinstance(emb, list) and len(emb) > 0:
                vec = np.asarray(emb[0]["embedding"], dtype=np.float32)
                norm = np.linalg.norm(vec)
                if norm > 0:
                    vec = vec / norm
                return vec
            if strict:
                raise RuntimeError(
                    "DeepFace returned no face embedding; cannot verify identity "
                    f"with detector '{detector_backend}'"
                )
        except Exception as exc:
            if strict:
                raise RuntimeError(
                    "DeepFace identity embedding failed (strict mode). "
                    f"Image={image_path} detector={detector_backend} "
                    f"error={type(exc).__name__}: {exc}"
                ) from exc
            # fall through to OpenCV fallback only in non-strict mode
            pass
    elif strict:
        raise RuntimeError(
            "DeepFace is unavailable; cannot verify identity. Face verification "
            "service requires the DeepFace identity backend."
        )

    if strict:
        raise RuntimeError(
            "DeepFace is unavailable; cannot verify identity (strict mode)."
        )

    # ---- OpenCV fallback: deterministic 512-dim descriptor ----
    # Uses color histograms + gradients so it is repeatable for the same image
    # (NOT a real identity embedding — only use this as a last resort, e.g.
    # for pipeline smoke-testing when DeepFace can't be installed at all).
    if not HAS_CV2:
        raise RuntimeError(
            "No embedding backend available: DeepFace failed/unavailable and "
            "OpenCV is not installed either."
        )

    img = _load_image(image_path)
    if img is None:
        raise ValueError("No image backend available to compute embedding")

    resized = cv2.resize(img, (32, 32), interpolation=cv2.INTER_AREA)
    gray = cv2.cvtColor(resized, cv2.COLOR_RGB2GRAY)
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    mag = np.sqrt(gx ** 2 + gy ** 2)

    color_flat = resized.astype(np.float32).flatten()  # 32*32*3 = 3072
    mag_flat = mag.flatten()  # 1024

    step_c = max(1, len(color_flat) // 384)
    step_m = max(1, len(mag_flat) // 128)
    feat = np.concatenate([
        color_flat[::step_c][:384],
        mag_flat[::step_m][:128],
    ]).astype(np.float32)

    if len(feat) < EMBEDDING_DIM:
        feat = np.pad(feat, (0, EMBEDDING_DIM - len(feat)))
    feat = feat[:EMBEDDING_DIM]
    norm = np.linalg.norm(feat)
    if norm > 0:
        feat = feat / norm
    return feat


def embedding_to_bytes(embedding: np.ndarray) -> bytes:
    """Pack a normalized 512-dim embedding into the schema's VARBINARY(512)."""
    vec = np.asarray(embedding, dtype=np.float32)
    if vec.size != EMBEDDING_DIM:
        raise ValueError(f"Expected {EMBEDDING_DIM} embedding values, received {vec.size}")
    norm = np.linalg.norm(vec)
    if norm > 0:
        vec = vec / norm
    quantized = np.clip(np.rint(vec * 127.0), -127, 127).astype(np.int8)
    return quantized.tobytes()


def bytes_to_embedding(raw: bytes) -> np.ndarray:
    """Unpack bytes back into a float32 embedding array."""
    if not raw:
        return np.zeros(EMBEDDING_DIM, dtype=np.float32)

    if len(raw) == EMBEDDING_DIM:
        arr = np.frombuffer(raw, dtype=np.int8).astype(np.float32) / 127.0
        norm = np.linalg.norm(arr)
        if norm > 0:
            arr = arr / norm
        return arr

    arr = np.frombuffer(raw, dtype=np.float32)
    if arr.size != EMBEDDING_DIM:
        arr = np.zeros(EMBEDDING_DIM, dtype=np.float32)
    return arr


def normalize_distance_metric(metric) -> str:
    """Normalize a distance-metric string to one of SUPPORTED_DISTANCE_METRICS."""
    if not metric:
        return "cosine"
    normalized = str(metric).strip().lower().replace("-", "_").replace(" ", "_")
    if normalized in ("euclidean_l2", "euclidean_l2_norm", "l2", "euclidean_l2norm"):
        return "euclidean_l2"
    if normalized in ("euclidean", "l2_norm", "l2norm"):
        return "euclidean"
    if normalized in ("cosine", "cosine_similarity"):
        return "cosine"
    return normalized


def compare_embeddings(a: np.ndarray, b: np.ndarray, metric: str = "cosine") -> float:
    """Compute a distance between two embeddings.

    Returns a distance value where lower means more similar.
    For cosine, returns 1 - cosine_similarity.
    For euclidean / euclidean_l2, returns the L2 norm of the difference.
    """
    metric = normalize_distance_metric(metric)
    a = np.asarray(a, dtype=np.float32)
    b = np.asarray(b, dtype=np.float32)
    if a.size != EMBEDDING_DIM or b.size != EMBEDDING_DIM:
        raise ValueError(f"Both embeddings must be {EMBEDDING_DIM}-dimensional")

    if metric == "cosine":
        na = np.linalg.norm(a)
        nb = np.linalg.norm(b)
        if na == 0 or nb == 0:
            return 1.0
        sim = float(np.dot(a, b) / (na * nb))
        return 1.0 - sim

    if metric in ("euclidean", "euclidean_l2"):
        return float(np.linalg.norm(a - b))

    raise ValueError(
        f"Unsupported distance metric '{metric}'. Supported: {', '.join(sorted(SUPPORTED_DISTANCE_METRICS))}"
    )
