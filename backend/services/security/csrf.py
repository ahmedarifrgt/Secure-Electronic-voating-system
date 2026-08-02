"""CSRF protection utilities.

For a stateless JWT-based API, CSRF is mitigated primarily by:
- Requiring the Authorization header (not cookies) for state-changing requests.
- Optionally validating a CSRF token header for session-cookie clients.

This module provides a lightweight double-submit token helper.
"""
import os
import hmac
import hashlib


def generate_csrf_token(session_token: str = "") -> str:
    """Generate a CSRF token derived from the session/secret."""
    secret = os.getenv("JWT_SECRET_KEY", "change-me-jwt-secret")
    message = (session_token or "anon").encode("utf-8")
    return hmac.new(secret.encode("utf-8"), message, hashlib.sha256).hexdigest()


def validate_csrf_token(token: str, session_token: str = "") -> bool:
    """Validate a CSRF token."""
    if not token:
        return False
    expected = generate_csrf_token(session_token)
    return hmac.compare_digest(token, expected)

