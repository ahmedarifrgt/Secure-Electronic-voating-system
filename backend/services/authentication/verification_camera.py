"""OpenCV camera capture flow for live face verification.

`registration_camera.py` only covers capturing the one-time registration
photo. Verification needs a *sequence* of real frames (for the liveness
blink/motion check in `liveness_detection.py`), captured live from the
webcam at verification time — never a static or mocked frame.

Flow:
1. Wait until exactly one face is detected, well lit, sharp, and fully
   inside the frame for a short stable period.
2. Once stable, grab a short burst of real frames a fraction of a second
   apart so `check_liveness` has genuine frame-to-frame motion to analyze.

If the webcam can't be opened or a stable face never appears, this raises
`VerificationCameraError` — it never falls back to a placeholder/mock image.
"""
from __future__ import annotations

import os
import tempfile
import time
from dataclasses import dataclass

from backend.services.authentication.opencv_utils import find_haar_cascade_path


@dataclass
class VerificationCaptureResult:
    frame_paths: list
    quality: dict
    face_box: tuple


class VerificationCameraError(RuntimeError):
    pass


class VerificationCamera:
    def __init__(self, camera_index: int = 0, stable_frames_required: int = 5,
                 burst_frames: int = 2, burst_interval: float = 0.25,
                 timeout_seconds: int = 30, save_dir: str | None = None):
        try:
            import cv2
        except Exception as exc:
            raise VerificationCameraError("OpenCV is required for live face verification") from exc

        self.cv2 = cv2
        self.camera_index = camera_index
        self.stable_frames_required = stable_frames_required
        self.burst_frames = max(2, burst_frames)
        self.burst_interval = burst_interval
        self.timeout_seconds = timeout_seconds
        self.save_dir = save_dir or tempfile.mkdtemp(prefix="face_verify_")

        cascade_path = find_haar_cascade_path(cv2)
        self.face_cascade = cv2.CascadeClassifier(cascade_path)
        if self.face_cascade.empty():
            raise VerificationCameraError("OpenCV face detector is unavailable")

    def _open_camera(self, cv2):
        backends = []
        if hasattr(cv2, "CAP_DSHOW"):
            backends.append(cv2.CAP_DSHOW)
        if hasattr(cv2, "CAP_MSMF"):
            backends.append(cv2.CAP_MSMF)
        if hasattr(cv2, "CAP_VFW"):
            backends.append(cv2.CAP_VFW)
        backends.append(None)

        last_error = None
        for backend in backends:
            try:
                cap = cv2.VideoCapture(self.camera_index, backend) if backend is not None else cv2.VideoCapture(self.camera_index)
                if cap.isOpened():
                    return cap
                cap.release()
            except Exception as exc:
                last_error = exc

        raise VerificationCameraError(
            "Unable to open webcam. Make sure the backend process runs on the "
            "machine that owns the camera and that no other app is using it."
            + (f" Last error: {last_error}" if last_error else "")
        )

    def _detect_faces(self, frame):
        cv2 = self.cv2
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        rects = self.face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=6)
        return [tuple(map(int, r)) for r in rects]

    def _quality(self, frame, faces):
        cv2 = self.cv2
        h, w = frame.shape[:2]
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        brightness = float(gray.mean())
        sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())

        reasons = []
        if len(faces) == 0:
            reasons.append("No face detected")
        elif len(faces) > 1:
            reasons.append("Multiple faces detected")
        if w < 640 or h < 480:
            reasons.append("Camera resolution too low")
        if brightness < 45:
            reasons.append("Lighting is too dark")
        if brightness > 220:
            reasons.append("Image is overexposed")
        if sharpness < 30:
            reasons.append("Image is too blurry")

        if len(faces) == 1:
            x, y, fw, fh = faces[0]
            area_ratio = (fw * fh) / float(w * h)
            if area_ratio < 0.05:
                reasons.append("Face is too small, move closer")
            margin = 10
            if x <= margin or y <= margin or x + fw >= w - margin or y + fh >= h - margin:
                reasons.append("Face is partially outside the frame")

        return {
            "passed": len(reasons) == 0,
            "message": reasons[0] if reasons else "Ready",
            "reasons": reasons,
            "details": {
                "brightness": round(brightness, 2),
                "sharpness": round(sharpness, 2),
                "resolution": f"{w}x{h}",
                "faces_detected": len(faces),
            },
        }

    def _draw_overlay(self, frame, faces, quality, message):
        cv2 = self.cv2
        color = (40, 180, 80) if quality["passed"] else (40, 90, 230)
        for (x, y, fw, fh) in faces:
            cv2.rectangle(frame, (x, y), (x + fw, y + fh), color, 2)
        cv2.putText(frame, message, (24, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2, cv2.LINE_AA)

    def capture(self) -> VerificationCaptureResult:
        cv2 = self.cv2
        cap = self._open_camera(cv2)
        stable_frames = 0
        started_at = time.monotonic()
        selected_quality = None
        selected_face = None

        try:
            while True:
                if time.monotonic() - started_at > self.timeout_seconds:
                    raise VerificationCameraError("Timed out waiting for a stable, well-lit face")

                ok, frame = cap.read()
                if not ok or frame is None:
                    continue

                faces = self._detect_faces(frame)
                quality = self._quality(frame, faces)
                stable_frames = stable_frames + 1 if quality["passed"] else 0

                self._draw_overlay(frame, faces, quality, quality["message"])
                cv2.imshow("Voter Verification - Face Capture", frame)
                key = cv2.waitKey(1) & 0xFF
                if key in (27, ord("q")):
                    raise VerificationCameraError("Face verification capture cancelled")

                if stable_frames >= self.stable_frames_required:
                    selected_quality = quality
                    selected_face = faces[0]
                    break

            # Positioning confirmed — grab a short burst of real frames so the
            # liveness stage has genuine frame-to-frame motion to analyze.
            frame_paths = []
            for i in range(self.burst_frames):
                ok, frame = cap.read()
                if not ok or frame is None:
                    continue
                path = os.path.join(self.save_dir, f"live_{int(time.time() * 1000)}_{i}.jpg")
                cv2.imwrite(path, frame, [int(cv2.IMWRITE_JPEG_QUALITY), 95])
                frame_paths.append(path)
                cv2.imshow("Voter Verification - Face Capture", frame)
                cv2.waitKey(1)
                if i < self.burst_frames - 1:
                    time.sleep(self.burst_interval)

            if len(frame_paths) < 2:
                raise VerificationCameraError("Failed to capture enough live frames from the webcam")

        finally:
            cap.release()
            cv2.destroyWindow("Voter Verification - Face Capture")

        return VerificationCaptureResult(frame_paths, selected_quality, selected_face)
