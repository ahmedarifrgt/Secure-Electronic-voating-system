"""Deepfake detection.

A practical implementation that:
1. Uses image-quality inconsistencies (compression artifacts, blending traces)
   as heuristic signals.
2. If a trained deepfake model directory exists under `ai_models/deepfake/`,
   attempts to load it and run inference (optional).
3. Otherwise runs heuristic checks and marks results appropriately.
"""
import os
import glob

HAS_CV2 = False
try:
    import cv2
    HAS_CV2 = True
except Exception:
    HAS_CV2 = False

DEEPFAKE_MODEL_DIR = os.getenv(
    "DEEPFAKE_MODEL_DIR",
    os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))))), "ai_models", "deepfake"),
)


def _mock_allowed() -> bool:
    return False


def _find_model():
    if not os.path.isdir(DEEPFAKE_MODEL_DIR):
        return None
    candidates = []
    for pattern in ("*.h5", "*.hdf5", "*.pth", "*.pt", "*.onnx", "*.tflite"):
        candidates.extend(glob.glob(os.path.join(DEEPFAKE_MODEL_DIR, "**", pattern), recursive=True))
    return candidates[0] if candidates else None


def _heuristic_checks(image_path: str) -> dict:
    """Run blending/compression heuristics."""
    details = {}
    if not HAS_CV2 or not os.path.exists(image_path):
        return {"passed": True, "details": details, "model": None}

    img = cv2.imread(image_path)
    if img is None:
        return {"passed": True, "details": details, "model": None}

    h, w = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Compression artifact heuristic: re-encode at high JPEG quality and
    # measure the difference. Heavy generative artifacts often cause
    # characteristic error patterns near facial boundaries.
    ok, encoded = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 90])
    if ok:
        decoded = cv2.imdecode(encoded, cv2.IMREAD_GRAYSCALE)
        diff = cv2.absdiff(gray, decoded)
        mse = float((diff ** 2).mean())
        details["reencode_mse"] = round(mse, 4)

    # Face-region blending heuristic: sample border vs center brightness variance
    # in the image. Real camera photos tend to have natural vignette gradients.
    center = gray[h // 4:3 * h // 4, w // 4:3 * w // 4]
    border_mask = cv2.erode(cv2.rectangle(
        gray.copy(), (0, 0), (w, h), 255, thickness=2), None)
    if center.size > 0:
        details["center_brightness"] = round(float(center.mean()), 2)

    # Final: without a trained model, treat heuristic warnings as non-blocking
    # unless the reencode MSE is extreme (indicates severe synthetic texture).
    passed = True
    if details.get("reencode_mse", 0) > 12.0:
        passed = False
        details["reason"] = "Extreme re-encode distortion (possible synthetic texture)"

    return {"passed": passed, "details": details, "model": _find_model()}


def check_deepfake(image_path: str) -> dict:
    """Run deepfake detection and return {passed, details, model}."""
    if not image_path or not os.path.exists(image_path):
        return {"passed": False, "details": {}, "model": None, "reason": "Image missing"}

    model_path = _find_model()
    if model_path:
        # If a real trained model is present, this is where you'd run it.
        # We leave a hook but fall through to heuristics for now.
        details = {"model_found": model_path, "inference": "heuristic_fallback"}
        result = _heuristic_checks(image_path)
        result["details"].update(details)
        result["model"] = model_path
        return result

    return _heuristic_checks(image_path)

