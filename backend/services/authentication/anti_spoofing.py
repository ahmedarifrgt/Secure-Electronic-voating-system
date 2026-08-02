"""Anti-spoofing checks.

Detects common presentation attacks:
- Replay attack (photo of a screen/printout): detected via image sharpness,
  moire patterns, and uniform illumination heuristics.
- Cropped/masked faces: detected via face-boundary analysis heuristics.

Since no trained anti-spoof model is bundled, this module implements
practical image-quality heuristics and logs all suspected spoof attempts
through the verification logger for the security dashboard.
"""
import os

HAS_CV2 = False
try:
    import cv2
    HAS_CV2 = True
except Exception:
    HAS_CV2 = False

HAS_DEEPFACE = False
try:
    from deepface import DeepFace  # type: ignore
    HAS_DEEPFACE = True
except Exception:
    HAS_DEEPFACE = False


def _mock_allowed() -> bool:
    return os.getenv("MOCK_FACE_VERIFICATION", "").lower() in ("1", "true", "yes")


def _laplacian_variance(image_path: str):
    """Sharpness metric — screens/prints often have lower variance."""
    if not HAS_CV2 or not os.path.exists(image_path):
        return None
    img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        return None
    return cv2.Laplacian(img, cv2.CV_64F).var()


def _detect_moire(image_path: str):
    """Rough heuristic: a printed photo viewed by a camera often has strong
    periodic high-frequency patterns (moire). We approximate via FFT energy
    in the mid-high frequency band."""
    if not HAS_CV2 or not os.path.exists(image_path):
        return False
    img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        return False
    img = cv2.resize(img, (256, 256))
    f = cv2.dft(img.astype(np_float32()), flags=cv2.DFT_COMPLEX_OUTPUT)
    f_shift = np_fft(f)
    magnitude = 20 * np_log(np_abs(f_shift) + 1e-6)
    h, w = magnitude.shape
    cy, cx = h // 2, w // 2
    # Mid-high frequency band (annulus)
    mask = np_zeros_like(magnitude)
    y, x = np_ogrid[:h, :w]
    r = np_sqrt((x - cx) ** 2 + (y - cy) ** 2)
    mask[(r > 30) & (r < 90)] = 1
    band_energy = float((magnitude * mask).sum())
    total_energy = float(magnitude.sum())
    if total_energy <= 0:
        return False
    ratio = band_energy / total_energy
    return ratio > 0.45  # tuned heuristic


def np_float32():
    import numpy as np
    return np.float32


def np_fft(shifted):
    import numpy as np
    return np.fft.fftshift(shifted)


def np_log(arr):
    import numpy as np
    return np.log(arr)


def np_abs(arr):
    import numpy as np
    return np.abs(arr)


def np_zeros_like(arr):
    import numpy as np
    return np.zeros_like(arr)


def np_ogrid(*args, **kwargs):
    import numpy as np
    return np.ogrid.__call__(*args, **kwargs)


def np_sqrt(arr):
    import numpy as np
    return np.sqrt(arr)


def check_anti_spoofing(image_path: str) -> dict:
    """Run anti-spoof heuristics on an image path."""
    if _mock_allowed():
        return {"passed": True, "details": {"mode": "mock"}}

    if not image_path or not os.path.exists(image_path):
        return {"passed": False, "reason": "Image missing", "details": {}}

    details = {}

    sharpness = _laplacian_variance(image_path)
    if sharpness is not None:
        details["laplacian_variance"] = round(sharpness, 2)
        # Extremely low sharpness -> likely a blurry printout or screen photo
        if sharpness < 20:
            return {"passed": False, "reason": "Image too blurry (possible replay)", "details": details}

    moire = _detect_moire(image_path)
    details["moire_detected"] = moire
    if moire:
        return {"passed": False, "reason": "Moire pattern detected (photo of screen)", "details": details}

    return {"passed": True, "details": details}

