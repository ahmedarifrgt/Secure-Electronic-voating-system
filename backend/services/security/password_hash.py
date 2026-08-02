"""Password hashing using Werkzeug's secure PBKDF2 (sha256)."""
from werkzeug.security import generate_password_hash, check_password_hash


def hash_password(password: str) -> str:
    """Return a salted hash string for the given plaintext password."""
    return generate_password_hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    """Check a plaintext password against a stored hash."""
    if not password_hash:
        return False
    return check_password_hash(password_hash, password)

