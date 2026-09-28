"""Entry point for the NID -> webcam -> face-verification flow.

Call `run_face_verification(nid, ...)` from your route/controller once the
voter has entered their NID. This wires together pieces that already exist
in this package:

- the registered face image path for that NID (from MySQL, or the default
  convention in `registered_face_storage.py` if you don't pass one in)
- a real webcam capture burst from `verification_camera.py` (no mock frames)
- the existing `verify_face_pipeline` in `face_verification.py`

NOTE: `stored_image_path` should be whatever your Voter model returns for
this NID's registered photo. If your MySQL schema instead stores a
precomputed embedding (VARBINARY(512)), fetch it and pass it via
`stored_embedding` instead — the pipeline supports both, but not both at once
(embedding takes priority if you pass it, since it avoids re-running DeepFace
on the registered image every time).
"""
import os

from backend.services.authentication.verification_camera import (
    VerificationCamera,
    VerificationCameraError,
)
from backend.services.authentication.face_verification import verify_face_pipeline
from backend.services.authentication.registered_face_storage import registered_face_path


def run_face_verification(nid: str, voter_id=None, stored_image_path: str | None = None,
                          stored_embedding=None, ip_address: str | None = None,
                          camera_index: int = 0) -> dict:
    """Run the full NID -> webcam -> verification flow.

    Args:
        nid: the voter's NID. Used to look up the registered image via the
             default convention if `stored_image_path` isn't supplied.
        voter_id: optional DB id, used only for logging.
        stored_image_path: path to the registered image as stored in MySQL
             for this NID. If omitted, falls back to
             `registered_face_storage.registered_face_path(nid)`.
        stored_embedding: optional precomputed 512-d embedding (as a numpy
             array, e.g. from `face_embedding.bytes_to_embedding`) if your
             schema stores embeddings instead of/alongside image paths.
        ip_address: for security-event logging.
        camera_index: which webcam to use (0 = default/built-in laptop cam).

    Returns:
        The same dict shape as `verify_face_pipeline`:
        {"passed": bool, "score": float, "details": {...}, "error": str|None}
    """
    registered_image = stored_image_path or str(registered_face_path(nid))
    if not os.path.exists(registered_image):
        return {
            "passed": False,
            "score": 0.0,
            "error": f"No registered face found for NID {nid}",
            "details": {},
        }

    try:
        camera = VerificationCamera(camera_index=camera_index)
        capture = camera.capture()
    except VerificationCameraError as exc:
        # No mock fallback — a camera/capture failure is a hard failure.
        return {"passed": False, "score": 0.0, "error": str(exc), "details": {}}

    frame_paths = capture.frame_paths
    live_image = frame_paths[-1]
    extra_frames = frame_paths[:-1]

    try:
        result = verify_face_pipeline(
            registered_image=registered_image,
            live_image=live_image,
            voter_id=voter_id,
            nid=nid,
            stored_embedding=stored_embedding,
            live_capture=True,   # real webcam burst just captured above
            extra_frames=extra_frames,
            ip_address=ip_address,
        )
    finally:
        # Clean up the temp burst frames regardless of outcome.
        for path in frame_paths:
            try:
                os.remove(path)
            except OSError:
                pass

    return result
