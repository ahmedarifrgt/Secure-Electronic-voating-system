"""Live webcam face tracking.

Opens the webcam, detects a face, then tracks it frame-to-frame using an
OpenCV object tracker (much smoother and cheaper than re-running face
detection on every single frame). Detection re-runs periodically to correct
drift or pick up a new face if the tracked one is lost.

Run directly:

    python live_face_tracking.py

Controls:
    q / Esc  - quit
    r        - force re-detection right now

Requires: opencv-contrib-python (for the CSRT tracker). If you only have
plain opencv-python installed, this falls back to KCF, then to
detection-only mode (re-detects every frame, still works, just less smooth).
"""
import time

import cv2
from backend.services.authentication.opencv_utils import find_haar_cascade_path

CAMERA_INDEX = 0
REDETECT_EVERY_SECONDS = 2.0
MIN_NEIGHBORS = 6
SCALE_FACTOR = 1.1


def make_tracker():
    """Return a fresh tracker instance, preferring CSRT (accurate) over
    KCF (faster but drifts more), and None if neither is available."""
    for factory_name in ("TrackerCSRT_create", "TrackerKCF_create"):
        factory = getattr(cv2, factory_name, None)
        if factory is not None:
            return factory()
        legacy = getattr(getattr(cv2, "legacy", None), factory_name, None)
        if legacy is not None:
            return legacy()
    return None


def detect_face(cascade, frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    faces = cascade.detectMultiScale(
        gray,
        scaleFactor=SCALE_FACTOR,
        minNeighbors=MIN_NEIGHBORS,
    )
    if len(faces) == 0:
        faces = cascade.detectMultiScale(
            gray,
            scaleFactor=1.15,
            minNeighbors=3,
        )
    if len(faces) == 0:
        return None
    # Track the largest detected face if more than one is present.
    faces = sorted(faces, key=lambda f: f[2] * f[3], reverse=True)
    return tuple(int(v) for v in faces[0])


def main():
    cascade_path = find_haar_cascade_path(cv2)
    cascade = cv2.CascadeClassifier(cascade_path)
    if cascade.empty():
        raise RuntimeError("Could not load Haar cascade for face detection")

    if hasattr(cv2, "CAP_DSHOW"):
        cap = cv2.VideoCapture(CAMERA_INDEX, cv2.CAP_DSHOW)
    else:
        cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        raise RuntimeError("Unable to open webcam. Check the camera index and that no other app is using it.")

    tracker = None
    tracking = False
    last_detect_time = 0.0
    fps_time = time.monotonic()
    fps_count = 0
    fps = 0.0

    print("Live face tracking running. Press 'q' to quit, 'r' to force re-detect.")

    try:
        while True:
            ok, frame = cap.read()
            if not ok or frame is None:
                continue

            now = time.monotonic()
            box = None
            status = "searching"

            need_redetect = (not tracking) or (now - last_detect_time > REDETECT_EVERY_SECONDS)

            if need_redetect:
                detected = detect_face(cascade, frame)
                last_detect_time = now
                if detected is not None:
                    tracker = make_tracker()
                    if tracker is not None:
                        tracker.init(frame, detected)
                        tracking = True
                        status = "detected"
                    else:
                        tracking = False
                        status = "detected (no tracker backend, redetecting every frame)"
                    box = detected
                else:
                    tracking = False
                    box = None
            elif tracking and tracker is not None:
                ok_track, tracked_box = tracker.update(frame)
                if ok_track:
                    box = tuple(int(v) for v in tracked_box)
                    status = "tracking"
                else:
                    tracking = False
                    status = "lost"

            if box is not None:
                x, y, w, h = box
                color = (40, 180, 80) if status in ("tracking", "detected") else (40, 90, 230)
                cv2.rectangle(frame, (x, y), (x + w, y + h), color, 2)
                cv2.putText(frame, status, (x, max(20, y - 10)),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2, cv2.LINE_AA)
            else:
                cv2.putText(frame, "No face detected", (24, 40),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (40, 90, 230), 2, cv2.LINE_AA)

            fps_count += 1
            if now - fps_time >= 1.0:
                fps = fps_count / (now - fps_time)
                fps_count = 0
                fps_time = now
            cv2.putText(frame, f"FPS: {fps:.1f}", (24, frame.shape[0] - 20),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 2, cv2.LINE_AA)

            cv2.imshow("Live Face Tracking", frame)
            key = cv2.waitKey(1) & 0xFF
            if key in (27, ord("q")):
                break
            if key == ord("r"):
                tracking = False
                last_detect_time = 0.0

    finally:
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()