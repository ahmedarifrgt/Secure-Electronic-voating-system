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
    DEEPFACE_MODEL = os.getenv("DEEPFACE_MODEL", "ArcFace")
    # 'mtcnn' is the default detector because it is installed and produces real
    # biometric identity embeddings. 'opencv' is NOT reliable here: the installed
    # opencv-contrib wheel ships no haarcascade XML data, so DeepFace.represent()
    # throws and the pipeline must never silently fall back to a weak descriptor.
    DEEPFACE_DETECTOR = os.getenv("DEEPFACE_DETECTOR", "mtcnn")
    # Detector backends DeepFace may use, in order of preference. The pipeline
    # probes each configured detector and fails closed if none can produce a
    # real embedding (never silently degrades to a non-identity descriptor).
    DEEPFACE_DETECTORS = [
        d.strip() for d in os.getenv(
            "DEEPFACE_DETECTORS", "mtcnn,opencv"
        ).split(",") if d.strip()
    ]
    DEEPFACE_DISTANCE_METRIC = os.getenv("DEEPFACE_DISTANCE_METRIC", "cosine").lower()
    # Keep verification responsive while still allowing ArcFace to load a model
    # and run inference on a local laptop webcam. The first run may still do a
    # one-time download, but the pipeline should remain within the 10–15s UX
    # target for normal subsequent checks.
    DEEPFACE_TIMEOUT_SECONDS = float(os.getenv("DEEPFACE_TIMEOUT_SECONDS", "60.0"))
    # Strict 1:1 cosine distance threshold. ArcFace cosine distance for the
    # same person is typically < 0.30; different people are usually > 0.45.
    # 0.30 is intentionally stricter to reject impostors reliably.
    FACE_THRESHOLD = float(os.getenv("FACE_THRESHOLD", "0.30"))

    # Uploads / temp
    UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", os.path.join(os.path.dirname(os.path.abspath(__file__)), "tmp"))
    REGISTERED_FACES_DIR = os.getenv(
        "REGISTERED_FACES_DIR",
        os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "datasets", "registered_faces"),
    )
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16 MB
