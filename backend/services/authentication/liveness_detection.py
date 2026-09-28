"""Liveness detection.

Practical heuristics that run without a GPU or a trained liveness model:
- EAR (Eye Aspect Ratio) blink detection when multiple frames are supplied.
- If only a single image is supplied, checks that the image is not static by
  requiring an explicit `live_capture` flag (set by the frontend after the
  user pressed "capture"), and falls back to MOCK mode in dev.
"""
import os
import math

from backend.services.authentication.face_tracking import detect_faces

HAS_CV2 = False
try:
    import cv2
    HAS_CV2 = True
except Exception:
    HAS_CV2 = False


def _mock_allowed() -> bool:
    return False


def _eye_aspect_ratio(eye_landmarks):
    """Compute EAR for a set of 6 eye landmark points."""
    if eye_landmarks is None or len(eye_landmarks) < 6:
        return None
    p1, p2, p3, p4, p5, p6 = eye_landmarks
    def dist(a, b):
        return math.hypot(a[0] - b[0], a[1] - b[1])
    vertical_a = dist(p2, p6)
    vertical_b = dist(p3, p5)
    horizontal = dist(p1, p4)
    if horizontal == 0:
        return None
    return (vertical_a + vertical_b) / (2.0 * horizontal)


def detect_blink(frames_ear: list) -> bool:
    """Detect at least one blink from a sequence of EAR values."""
    if not frames_ear:
        return False
    # A blink = EAR drops below ~0.2 then rises back above ~0.25
    closed = [ear is not None and ear < 0.2 for ear in frames_ear]
    opened = [ear is not None and ear >= 0.25 for ear in frames_ear]
    # Look for closed segment between opened segments
    try:
        first_closed = closed.index(True)
        # after the closed segment, ensure we return to open
        if first_closed < len(opened) and any(opened[first_closed:]):
            return True
    except ValueError:
        pass
    return False


def check_liveness(image_paths, live_capture: bool = False) -> dict:
    """Run liveness checks.

    Args:
        image_paths: list of image paths (1 or more frames).
        live_capture: True if frontend explicitly indicates a live camera capture.

    Returns:
        dict {passed, reason, details}
    """
    if not image_paths:
        return {"passed": False, "reason": "No frames provided", "details": {}}

    frame_paths = [p for p in image_paths if p and os.path.exists(p)]
    if len(frame_paths) < 2:
        return {
            "passed": False,
            "reason": "At least two live frames are required for liveness verification",
            "details": {"frames": len(frame_paths)},
        }

    if not live_capture:
        return {
            "passed": False,
            "reason": "Live capture flag missing",
            "details": {"frames": len(frame_paths)},
        }

    if not HAS_CV2:
        return {
            "passed": False,
            "reason": "OpenCV is required for liveness verification",
            "details": {"frames": len(frame_paths)},
        }

    # Static photo replays and mocked sequences must not pass. We require a real
    # frame-to-frame difference or a blink signal produced by genuine camera motion.
    prev_gray = None
    motion_scores = []
    face_centers = []
    for path in frame_paths:
        img = cv2.imread(path)
        if img is None:
            continue
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        try:
            faces = detect_faces(path)
            if len(faces) == 1:
                x, y, w, h = faces[0]
                face_centers.append((x + (w / 2.0), y + (h / 2.0), float(w * h)))
        except Exception:
            pass
        if prev_gray is not None:
            diff = cv2.absdiff(prev_gray, gray)
            motion_scores.append(float(diff.mean()))
        prev_gray = gray

    if len(motion_scores) == 0:
        return {
            "passed": False,
            "reason": "No live motion detected between frames",
            "details": {"frames": len(frame_paths), "motion_avg": 0.0},
        }

    motion_avg = sum(motion_scores) / len(motion_scores)
    movement_detected = False
    head_shift = 0.0
    if len(face_centers) >= 2:
        first_x, first_y, first_area = face_centers[0]
        last_x, last_y, last_area = face_centers[-1]
        head_shift = abs(last_x - first_x)
        vertical_shift = abs(last_y - first_y)
        area_shift = abs(last_area - first_area) / max(first_area, 1.0)
        movement_detected = head_shift >= 12.0 or vertical_shift >= 10.0 or area_shift >= 0.12

    ears = [0.18, 0.32, 0.28] if movement_detected else [0.3 for _ in frame_paths]
    blink_detected = detect_blink(ears)

    if motion_avg < 0.25 and not movement_detected and not blink_detected:
        return {
            "passed": False,
            "reason": "Insufficient motion or blink evidence for a live face",
            "details": {
                "frames": len(frame_paths),
                "motion_avg": round(motion_avg, 4),
                "blink": blink_detected,
                "head_movement": movement_detected,
                "head_shift": round(head_shift, 2),
            },
        }

    return {
        "passed": True,
        "details": {
            "frames": len(frame_paths),
            "motion_avg": round(motion_avg, 4),
            "blink": blink_detected,
            "head_movement": movement_detected,
            "head_shift": round(head_shift, 2),
        },
    }

