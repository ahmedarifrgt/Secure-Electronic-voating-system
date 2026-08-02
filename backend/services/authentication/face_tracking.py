"""Face tracking checks.

Verifies the captured image contains exactly one detectable face (no multiple
people, no overlays). Uses OpenCV Haar cascades / DeepFace detector when
available; otherwise falls back to heuristic checks driven by config.
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


def detect_faces(image_path: str):
    """Return a list of face bounding boxes [(x, y, w, h), ...]."""
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found: {image_path}")

    if HAS_DEEPFACE:
        try:
            faces = DeepFace.detectFace(
                img_path=image_path,
                detector_backend="mtcnn",
                enforce_detection=False,
            )
            if isinstance(faces, list):
                return [tuple(getattr(f, "bbox", (0, 0, 0, 0))) for f in faces]
            # DeepFace returns single ndarray when one face
            return [(0, 0, 0, 0)] if faces is not None else []
        except Exception:
            pass

    if HAS_CV2:
        cascade_path = os.path.join(
            os.path.dirname(cv2.__file__), "data", "haarcascade_frontalface_default.xml"
        )
        if os.path.exists(cascade_path):
            cascade = cv2.CascadeClassifier(cascade_path)
            img = cv2.imread(image_path)
            if img is not None:
                gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
                rects = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
                return [tuple(map(int, r)) for r in rects]

    # No detector available — in mock mode assume one face
    if _mock_allowed():
        return [(0, 0, 0, 0)]
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

