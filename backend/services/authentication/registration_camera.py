"""OpenCV camera capture flow for voter registration."""
from __future__ import annotations

import time
from dataclasses import dataclass

from backend.services.authentication.live_face_tracking import detect_face, make_tracker
from backend.services.authentication.opencv_utils import find_haar_cascade_path


@dataclass
class CaptureResult:
    frame: object
    quality: dict
    face_box: tuple[int, int, int, int]


class RegistrationCameraError(RuntimeError):
    pass


class RegistrationCamera:
    def __init__(self, camera_index: int = 0, countdown_seconds: int = 3,
                 stable_frames_required: int = 12, timeout_seconds: int = 90,
                 redetect_every_seconds: float = 2.5):
        try:
            import cv2
        except Exception as exc:
            raise RegistrationCameraError("OpenCV is required for voter face capture") from exc

        if not hasattr(cv2, "CascadeClassifier"):
            raise RegistrationCameraError(
                "Your OpenCV package does not support webcam face detection. "
                "Install opencv-python or opencv-contrib-python, not opencv-python-headless."
            )

        self.cv2 = cv2
        self.camera_index = camera_index
        self.countdown_seconds = countdown_seconds
        self.stable_frames_required = stable_frames_required
        self.timeout_seconds = timeout_seconds
        self.redetect_every_seconds = redetect_every_seconds
        self.tracker = None
        self.tracking = False
        self.last_detect_time = 0.0

        cascade_path = find_haar_cascade_path(self.cv2)
        self.face_cascade = self.cv2.CascadeClassifier(cascade_path)
        if self.face_cascade is None or self.face_cascade.empty():
            raise RegistrationCameraError(
                "OpenCV face detector is unavailable. "
                "Install opencv-python or opencv-contrib-python with bundled Haar cascades."
            )

    def _open_camera(self, cv2):
        backends = []
        if hasattr(cv2, 'CAP_DSHOW'):
            backends.append(cv2.CAP_DSHOW)
        if hasattr(cv2, 'CAP_MSMF'):
            backends.append(cv2.CAP_MSMF)
        if hasattr(cv2, 'CAP_VFW'):
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

        raise RegistrationCameraError(
            "Unable to open webcam. Please verify camera connection and run the backend from the host system with camera access."
            + (f" Last error: {last_error}" if last_error else "")
        )

    def capture(self) -> CaptureResult:
        cv2 = self.cv2
        cap = self._open_camera(cv2)

        stable_frames = 0
        countdown_started_at = None
        selected_frame = None
        selected_quality = None
        selected_face = None
        started_at = time.monotonic()

        try:
            while time.monotonic() - started_at < self.timeout_seconds:
                ok, frame = cap.read()
                if not ok or frame is None:
                    continue

                faces = self._detect_faces(frame)
                quality = self._quality(frame, faces)
                ready = quality["passed"]

                if ready:
                    stable_frames += 1
                    if stable_frames >= self.stable_frames_required and countdown_started_at is None:
                        countdown_started_at = time.monotonic()
                    if countdown_started_at is not None:
                        remaining = self.countdown_seconds - int(time.monotonic() - countdown_started_at)
                        if remaining <= 0:
                            selected_frame = frame.copy()
                            selected_quality = quality
                            selected_face = faces[0]
                            break
                        self._draw_overlay(frame, faces, quality, f"Capturing in {remaining}")
                    else:
                        self._draw_overlay(frame, faces, quality, "Hold still")
                else:
                    stable_frames = 0
                    countdown_started_at = None
                    self._draw_overlay(frame, faces, quality, quality["message"])

                cv2.imshow("Create Voter - Face Capture", frame)
                key = cv2.waitKey(1) & 0xFF
                if key in (27, ord("q")):
                    raise RegistrationCameraError("Face capture cancelled")
            else:
                raise RegistrationCameraError("Face capture timed out")
        finally:
            cap.release()
            cv2.destroyWindow("Create Voter - Face Capture")

        return CaptureResult(selected_frame, selected_quality, selected_face)

    def _detect_faces(self, frame) -> list[tuple[int, int, int, int]]:
        now = time.monotonic()
        if self.tracker is not None and self.tracking:
            ok, box = self.tracker.update(frame)
            if ok and box is not None:
                self.last_detect_time = now
                x, y, w, h = [int(v) for v in box]
                return [(x, y, w, h)]
            self.tracking = False

        if now - self.last_detect_time < self.redetect_every_seconds and self.tracker is not None:
            # Tracker exists but has been lost; force a new detection after the interval.
            pass

        detected = detect_face(self.face_cascade, frame)
        self.last_detect_time = now
        if detected is None:
            self.tracker = None
            self.tracking = False
            return []

        self.tracker = make_tracker()
        if self.tracker is not None:
            try:
                self.tracker.init(frame, detected)
                self.tracking = True
            except Exception:
                self.tracking = False

        return [detected]

    def _quality(self, frame, faces) -> dict:
        cv2 = self.cv2
        height, width = frame.shape[:2]
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        brightness = float(gray.mean())
        sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())

        reasons = []
        if len(faces) == 0:
            reasons.append("No face detected")
        if len(faces) > 1:
            reasons.append("Multiple faces detected")
        if width < 640 or height < 480:
            reasons.append("Camera resolution is too low")
        if brightness < 45:
            reasons.append("Lighting is too dark")
        if brightness > 220:
            reasons.append("Image is overexposed")
        if sharpness < 35:
            reasons.append("Face image is too blurry")

        centered = False
        if len(faces) == 1:
            x, y, face_width, face_height = faces[0]
            margin = 12
            if x <= margin or y <= margin or x + face_width >= width - margin or y + face_height >= height - margin:
                reasons.append("Face is partially outside the frame")
            area_ratio = (face_width * face_height) / float(width * height)
            if area_ratio < 0.06:
                reasons.append("Face is too small")
            frame_center_x = width / 2.0
            frame_center_y = height / 2.0
            face_center_x = x + face_width / 2.0
            face_center_y = y + face_height / 2.0
            distance = ((face_center_x - frame_center_x) ** 2 + (face_center_y - frame_center_y) ** 2) ** 0.5
            centered = bool(distance < min(width, height) * 0.12)
            if not centered:
                reasons.append("Center the face inside the guide")

        return {
            "passed": len(reasons) == 0,
            "message": reasons[0] if reasons else "Ready",
            "reasons": reasons,
            "details": {
                "brightness": round(brightness, 2),
                "sharpness": round(sharpness, 2),
                "resolution": f"{width}x{height}",
                "faces_detected": len(faces),
                "centered": centered,
            },
        }

    def _draw_overlay(self, frame, faces, quality, message: str) -> None:
        cv2 = self.cv2
        height, width = frame.shape[:2]
        guide_width = int(width * 0.32)
        guide_height = int(height * 0.48)
        guide_x = (width - guide_width) // 2
        guide_y = (height - guide_height) // 2
        color = (40, 180, 80) if quality["passed"] else (40, 90, 230)
        cv2.rectangle(frame, (guide_x, guide_y), (guide_x + guide_width, guide_y + guide_height), color, 2)
        for x, y, face_width, face_height in faces:
            cv2.rectangle(frame, (x, y), (x + face_width, y + face_height), color, 2)
        cv2.putText(frame, message, (24, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2, cv2.LINE_AA)
