import numpy as np
import pytest

from backend.services.authentication import face_embedding


def test_generate_embedding_defaults_to_strict_identity_mode(tmp_path, monkeypatch):
    image_path = tmp_path / "face.jpg"
    image_path.write_bytes(b"fake-image")

    monkeypatch.setattr(face_embedding, "_deepface", lambda: face_embedding._SENTINEL)
    monkeypatch.setattr(face_embedding, "HAS_CV2", True)
    monkeypatch.setattr(face_embedding, "_load_image", lambda path: np.zeros((32, 32, 3), dtype=np.uint8))

    with pytest.raises(RuntimeError, match="cannot verify identity"):
        face_embedding.generate_embedding(str(image_path))
