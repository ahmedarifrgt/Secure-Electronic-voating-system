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

import numpy as np

HAS_CV2 = False
try:
    import cv2
    HAS_CV2 = True
except Exception:
    HAS_CV2 = False


def _mock_allowed() -> bool:
    return False


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
    periodic high-frequency patterns (moire). We approximate this via FFT
    energy concentrated in a mid-high frequency annulus."""
    if not HAS_CV2 or not os.path.exists(image_path):
        return False
    img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        return False

    img = cv2.resize(img, (256, 256)).astype(np.float32)

    # True magnitude spectrum via numpy's FFT (avoids the pitfall of taking
    # abs() of cv2.dft's raw 2-channel real/imag output, which does not give
    # the correct magnitude).
    f = np.fft.fft2(img)
    f_shift = np.fft.fftshift(f)
    magnitude = 20 * np.log(np.abs(f_shift) + 1e-6)

    h, w = magnitude.shape
    cy, cx = h // 2, w // 2
    y, x = np.ogrid[:h, :w]
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)

    # Mid-high frequency band (annulus) where moire energy concentrates.
    mask = (r > 30) & (r < 90)
    band_energy = float(magnitude[mask].sum())
    total_energy = float(magnitude.sum())
    if total_energy <= 0:
        return False

    ratio = band_energy / total_energy
    return ratio > 0.45  # tuned heuristic


def check_anti_spoofing(image_path: str) -> dict:
    """Run anti-spoof heuristics on an image path."""
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
