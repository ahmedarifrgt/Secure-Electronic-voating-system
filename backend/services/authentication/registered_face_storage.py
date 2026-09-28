"""Secure storage for registered voter face images."""
from pathlib import Path

from backend.config import Config


def registered_face_path(nid: str) -> Path:
    clean_nid = "".join(ch for ch in str(nid) if ch.isdigit())
    if clean_nid != str(nid):
        raise ValueError("NID must contain digits only")
    return Path(Config.REGISTERED_FACES_DIR) / f"{clean_nid}.jpg"


def save_registered_face(nid: str, frame, replace_existing: bool = False) -> str:
    import cv2

    target = registered_face_path(nid)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and not replace_existing:
        raise FileExistsError("A registered face image already exists for this NID")
    ok = cv2.imwrite(str(target), frame, [int(cv2.IMWRITE_JPEG_QUALITY), 95])
    if not ok:
        raise IOError("Failed to save registered face image")
    return str(target)


def move_registered_face(old_nid: str, new_nid: str, replace_existing: bool = False) -> str:
    source = registered_face_path(old_nid)
    target = registered_face_path(new_nid)
    target.parent.mkdir(parents=True, exist_ok=True)

    if source == target:
        return str(target)

    if target.exists() and not replace_existing:
        raise FileExistsError("A registered face image already exists for this NID")

    if source.exists():
        source.replace(target)

    return str(target)
