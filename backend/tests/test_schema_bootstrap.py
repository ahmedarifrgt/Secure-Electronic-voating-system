import shutil
import tempfile

from sqlalchemy import inspect

from backend.app import create_app, db
from backend.config import Config


def test_create_app_bootstraps_missing_tables():
    original_uri = Config.SQLALCHEMY_DATABASE_URI
    tmp_dir = tempfile.mkdtemp()
    try:
        Config.SQLALCHEMY_DATABASE_URI = f"sqlite:///{tmp_dir}/bootstrap.db"
        app = create_app()

        with app.app_context():
            inspector = inspect(db.engine)
            assert inspector.has_table("candidates")
            assert inspector.has_table("elections")
            assert inspector.has_table("votes")

        with app.app_context():
            db.session.remove()
            db.engine.dispose()
    finally:
        Config.SQLALCHEMY_DATABASE_URI = original_uri
        shutil.rmtree(tmp_dir, ignore_errors=True)
