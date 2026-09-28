import os
import tempfile

from backend.services.authentication.liveness_detection import check_liveness
from backend.services.authentication.opencv_utils import find_haar_cascade_path


def test_liveness_rejects_static_replay_even_with_live_capture_flag():
    with tempfile.TemporaryDirectory() as tmp_dir:
        frame_a = os.path.join(tmp_dir, 'a.jpg')
        frame_b = os.path.join(tmp_dir, 'b.jpg')
        with open(frame_a, 'wb') as fh:
            fh.write(b'fake-image-a')
        with open(frame_b, 'wb') as fh:
            fh.write(b'fake-image-b')

        result = check_liveness([frame_a, frame_b], live_capture=True)
        assert result['passed'] is False


def test_haar_cascade_path_resolves():
    import cv2

    cascade_path = find_haar_cascade_path(cv2)
    assert os.path.exists(cascade_path)
