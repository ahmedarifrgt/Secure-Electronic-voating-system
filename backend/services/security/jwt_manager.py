"""JWT token creation, decoding, and verification."""
import os
from datetime import datetime, timedelta, timezone

import jwt

from backend.config import Config

JWT_SECRET_KEY = Config.JWT_SECRET_KEY
ALGORITHM = "HS256"


def create_jwt_token(payload: dict, expires_hours: int = None) -> str:
    """Create a signed JWT token with expiry."""
    exp_hours = expires_hours or int(os.getenv("JWT_EXPIRY_HOURS", "8"))
    now = datetime.now(timezone.utc)
    token_payload = dict(payload)
    token_payload["iat"] = now
    token_payload["exp"] = now + timedelta(hours=exp_hours)
    return jwt.encode(token_payload, JWT_SECRET_KEY, algorithm=ALGORITHM)


def decode_jwt_token(token: str):
    """Decode and validate a JWT. Returns payload or None."""
    try:
        return jwt.decode(token, JWT_SECRET_KEY, algorithms=[ALGORITHM])
    except Exception:
        return None


def get_token_from_header(auth_header: str):
    if not auth_header:
        return None
    if auth_header.startswith("Bearer "):
        return auth_header[7:]
    return auth_header

