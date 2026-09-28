"""Image quality validation.

Ensures the captured image is suitable for reliable face verification:
- minimum resolution
- brightness within range (not over/under-exposed)
- not excessively blurry
- valid image file
"""
import os

HAS_CV2 = False
try:
    import cv2
    HAS_CV2 = True
except Exception:
    HAS_CV2 = False

MIN_WIDTH = 224
MIN_HEIGHT = 224
MIN_BRIGHTNESS = 40
MAX_BRIGHTNESS = 220
MIN_LAPLACIAN_VAR = 22.0


def _mock_allowed() -> bool:
    return False


def validate_image_quality(image_path: str) -> dict:
    """Validate image quality; returns {passed, reasons[], details}."""
    if not image_path or not os.path.exists(image_path):
        return {"passed": False, "reasons": ["Image file not found"], "details": {}}

    if not HAS_CV2:
        return {"passed": False, "reasons": ["OpenCV is required"], "details": {}}

    img = cv2.imread(image_path)
    if img is None:
        return {"passed": False, "reasons": ["Unreadable image file"], "details": {}}

    h, w = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    brightness = float(gray.mean())
    laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())

    reasons = []
    if w < MIN_WIDTH or h < MIN_HEIGHT:
        reasons.append(f"Resolution too low: {w}x{h}")
    if brightness < MIN_BRIGHTNESS:
        reasons.append(f"Image too dark (brightness {brightness:.1f})")
    if brightness > MAX_BRIGHTNESS:
        reasons.append(f"Image overexposed (brightness {brightness:.1f})")
    if laplacian_var < MIN_LAPLACIAN_VAR:
        reasons.append(f"Image too blurry (sharpness {laplacian_var:.1f})")

    details = {
        "resolution": f"{w}x{h}",
        "brightness": round(brightness, 2),
        "sharpness": round(laplacian_var, 2),
    }
    return {
        "passed": len(reasons) == 0,
        "reasons": reasons,
        "details": details,
    }

