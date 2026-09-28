"""Shared OpenCV utility functions for backend face capture and detection."""

import os
import tempfile
import urllib.request
from pathlib import Path


def _download_haar_cascade(cascade_name: str) -> str:
    project_root = Path(__file__).resolve().parents[3]
    cache_dir = Path(os.getenv("OPENCV_CASCADE_CACHE_DIR", project_root / "backend" / "tmp" / "opencv_cascades")).resolve()
    cache_dir.mkdir(parents=True, exist_ok=True)
    cascade_path = cache_dir / cascade_name
    if cascade_path.exists():
        return str(cascade_path)

    url = f"https://raw.githubusercontent.com/opencv/opencv/master/data/haarcascades/{cascade_name}"
    try:
        with urllib.request.urlopen(url, timeout=15) as response:
            data = response.read()
        cascade_path.write_bytes(data)
        return str(cascade_path)
    except Exception as exc:
        raise RuntimeError(
            f"Failed to download Haar cascade from {url}. "
            "Check network access or preinstall a supported OpenCV package with bundled cascades."
        ) from exc


def find_haar_cascade_path(cv2) -> str:
    """Return a valid path to the Haar cascade XML file for OpenCV.

    Tries the OpenCV-provided data directory first, then a few common
    fallback locations relative to the installed cv2 package. If no packaged
    cascade is found, it downloads a local copy into a cache directory.
    """
    if cv2 is None:
        raise RuntimeError("OpenCV is not imported")

    cascade_name = "haarcascade_frontalface_default.xml"
    candidates = []

    cascade_dir = getattr(cv2.data, "haarcascades", None)
    if cascade_dir:
        candidates.append(os.path.join(cascade_dir, cascade_name))

    if hasattr(cv2, "__file__"):
        base_dir = os.path.dirname(cv2.__file__)
        candidates.extend([
            os.path.join(base_dir, "data", cascade_name),
            os.path.join(base_dir, cascade_name),
            os.path.normpath(os.path.join(base_dir, "..", "share", "opencv4", "haarcascades", cascade_name)),
            os.path.normpath(os.path.join(base_dir, "..", "..", "share", "opencv4", "haarcascades", cascade_name)),
        ])

    for candidate in candidates:
        if candidate and os.path.exists(candidate):
            return candidate

    try:
        return _download_haar_cascade(cascade_name)
    except Exception as exc:
        details = {
            "cv2_file": getattr(cv2, "__file__", None),
            "cv2_data_haarcascades": cascade_dir,
            "checked_paths": candidates,
        }
        raise RuntimeError(
            "OpenCV Haar cascade file not found and automatic download failed. "
            "Install a supported OpenCV package with bundled Haar cascades, such as "
            "`opencv-contrib-python>=4.8.0.74,<5` or `opencv-python>=4.8.0,<5`, "
            "and reinstall backend dependencies in the active virtual environment. "
            f"Details: {details}"
        ) from exc
