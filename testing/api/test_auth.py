import pytest
from backend import create_app, db

@pytest.fixture
def client():
    app = create_app()
    app.testing = True
    with app.test_client() as client:
        yield client

def test_login_invalid_nid(client):
    response = client.post("/auth/login", json={"nid": "000000", "live_image_path": "test.jpg"})
    assert response.status_code == 401

def test_login_face_verification_fail(client):
    response = client.post("/auth/login", json={"nid": "1234567890", "live_image_path": "wrong_face.jpg"})
    assert response.status_code == 403
