import tempfile

from backend.app import create_app, db
from backend.config import Config
from backend.models.vote import Vote
from backend.services.security.jwt_manager import create_jwt_token
import backend.routes.report as report_route


def test_admin_can_verify_vote_token():
    original_db_uri = Config.SQLALCHEMY_DATABASE_URI
    with tempfile.TemporaryDirectory() as tmp_dir:
        Config.SQLALCHEMY_DATABASE_URI = f"sqlite:///{tmp_dir}/test.db"
        app = create_app()
        app.config.update(TESTING=True, WTF_CSRF_ENABLED=False)

        with app.app_context():
            db.create_all()

            vote = Vote(
                election_id=10,
                voter_id=20,
                candidate_id=30,
                encrypted_vote=b"encrypted",
                hash="a" * 64,
                signature="signature",
                iv="b" * 32,
                token="c" * 64,
            )
            db.session.add(vote)
            db.session.commit()

        token = create_jwt_token({"role": "admin", "sub": "admin"})

        def _valid_integrity(_vote):
            return {"valid": True, "reasons": []}

        original = report_route.check_vote_integrity
        report_route.check_vote_integrity = _valid_integrity
        try:
            with app.test_client() as client:
                response = client.post(
                    "/report/verify-token",
                    json={"token": "c" * 64},
                    headers={"Authorization": f"Bearer {token}"},
                )

            assert response.status_code == 200
            data = response.get_json()
            assert data["found"] is True
            assert data["valid"] is True
            assert data["token"] == "c" * 64
            assert data["is_verified"] is True
            assert data["vote_id"] is not None
        finally:
            with app.app_context():
                db.session.remove()
                db.engine.dispose()
            report_route.check_vote_integrity = original
            Config.SQLALCHEMY_DATABASE_URI = original_db_uri
