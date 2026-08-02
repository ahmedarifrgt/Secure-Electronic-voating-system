import os
from datetime import timedelta
from dotenv import load_dotenv

# Load .env from project root or backend directory
load_dotenv()
load_dotenv(dotenv_path=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env'))


class Config:
    # Core
    SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        "mysql+pymysql://root:password@localhost/voting_system"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # JWT
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "change-me-jwt-secret")
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=int(os.getenv("JWT_EXPIRY_HOURS", "8")))

    # Session
    SESSION_TIMEOUT = int(os.getenv("SESSION_TIMEOUT", "1800"))  # 30 minutes

    # Cryptography
    AES_KEY = os.getenv("AES_KEY", "0123456789abcdef0123456789abcdef")  # 32 bytes for AES-256
    RSA_PRIVATE_KEY_PATH = os.getenv(
        "RSA_PRIVATE_KEY_PATH",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "keys", "private.pem")
    )
    RSA_PUBLIC_KEY_PATH = os.getenv(
        "RSA_PUBLIC_KEY_PATH",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "keys", "public.pem")
    )

    # Admin (defaults for dev; override in .env)
    ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "Admin@123")
    ADMIN_PASSWORD_HASH = os.getenv("ADMIN_PASSWORD_HASH", "")

    # Face verification
    MOCK_FACE_VERIFICATION = os.getenv("MOCK_FACE_VERIFICATION", "").lower() in ("1", "true", "yes")
    DEEPFACE_MODEL = os.getenv("DEEPFACE_MODEL", "Facenet")
    DEEPFACE_DETECTOR = os.getenv("DEEPFACE_DETECTOR", "mtcnn")
    FACE_THRESHOLD = float(os.getenv("FACE_THRESHOLD", "0.6"))

    # Uploads / temp
    UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", os.path.join(os.path.dirname(os.path.abspath(__file__)), "tmp"))
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16 MB

