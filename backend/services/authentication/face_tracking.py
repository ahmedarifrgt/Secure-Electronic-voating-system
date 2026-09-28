"""Face tracking checks.

Verifies the captured image contains exactly one detectable face (no multiple
people, no overlays). Uses OpenCV Haar cascades / DeepFace detector when
available; otherwise falls back to heuristic checks driven by config.
"""
import os

from backend.config import Config
from backend.services.authentication.opencv_utils import find_haar_cascade_path

HAS_CV2 = False
try:
    import cv2
    HAS_CV2 = True
except Exception:
    HAS_CV2 = False

# Non-blocking DeepFace access. The installed deepface stack can deadlock the
# process under `from deepface import DeepFace`, so we never import it at
# module scope — use `_deepface()` to obtain the module lazily.
from backend.services.authentication._deepface_loader import (
    deepface as _deepface,
    _SENTINEL,
)

HAS_DEEPFACE = False


def _mock_allowed() -> bool:
    return False


def detect_faces(image_path: str):
    """Return a list of face bounding boxes [(x, y, w, h), ...]."""
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found: {image_path}")

    # Haar detection is much faster than invoking DeepFace for every frame.
    # DeepFace is still required later for the actual identity embedding.
    if HAS_CV2:
        try:
            cascade_path = find_haar_cascade_path(cv2)
            cascade = cv2.CascadeClassifier(cascade_path)
            if not cascade.empty():
                img = cv2.imread(image_path)
                if img is not None:
                    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
                    rects = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
                    if len(rects) == 0:
                        rects = cascade.detectMultiScale(gray, scaleFactor=1.15, minNeighbors=3)
                    if len(rects) > 0:
                        return [tuple(map(int, r)) for r in rects]
        except Exception:
            pass

    DeepFace = _deepface()
    if DeepFace is not _SENTINEL:
        try:
            detector_backend = getattr(Config, "DEEPFACE_DETECTOR", "mtcnn")
            detected = DeepFace.extract_faces(
                img_path=image_path,
                detector_backend=detector_backend,
                enforce_detection=True,
                align=True,
            )
            faces = []
            for item in detected or []:
                region = item.get("facial_area") if isinstance(item, dict) else None
                if isinstance(region, dict):
                    faces.append((
                        int(region.get("x", 0)),
                        int(region.get("y", 0)),
                        int(region.get("w", 0)),
                        int(region.get("h", 0)),
                    ))
            if faces:
                return faces
        except Exception:
            pass

    raise RuntimeError("No face detector backend available")


def check_face_tracking(image_path: str) -> dict:
    """Ensure exactly one face is present and clearly visible."""
    try:
        faces = detect_faces(image_path)
    except Exception as e:
        return {"passed": False, "error": str(e), "faces": 0}

    count = len(faces)
    # Practical rule: exactly one face, and its bounding box is large enough
    # to indicate a real capture (not a distant/pixelated face).
    passed = count == 1
    details = {"faces_detected": count}
    if passed and HAS_CV2 and faces and faces[0] != (0, 0, 0, 0):
        img = cv2.imread(image_path)
        if img is not None:
            h, w = img.shape[:2]
            _, _, fw, fh = faces[0]
            face_area = (fw * fh) / (w * h) if w * h > 0 else 0
            details["face_area_ratio"] = round(face_area, 4)
            if face_area < 0.01:
                passed = False
                details["reason"] = "Face too small in frame"

    if passed:
        return {"passed": True, "details": details}
    return {"passed": False, "details": details, "reason": "Expected exactly one face"}
