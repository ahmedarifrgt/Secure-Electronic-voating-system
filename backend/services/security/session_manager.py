"""Session management utilities."""
import os
import time
import uuid
import threading
from datetime import datetime, timedelta

SESSION_TIMEOUT = int(os.getenv("SESSION_TIMEOUT", "1800"))  # seconds

_sessions = {}
_lock = threading.Lock()


def create_session(user_id, role="voter"):
    """Create a session token with expiry."""
    token = uuid.uuid4().hex
    expires_at = datetime.now() + timedelta(seconds=SESSION_TIMEOUT)
    with _lock:
        _sessions[token] = {
            "user_id": user_id,
            "role": role,
            "created_at": datetime.now(),
            "expires_at": expires_at,
        }
    return token


def validate_session(token):
    """Return session dict if valid, else None."""
    with _lock:
        sess = _sessions.get(token)
        if not sess:
            return None
        if datetime.now() > sess["expires_at"]:
            _sessions.pop(token, None)
            return None
        return sess


def invalidate_session(token):
    with _lock:
        _sessions.pop(token, None)


def cleanup_sessions():
    now = datetime.now()
    with _lock:
        expired = [k for k, v in _sessions.items() if now > v["expires_at"]]
        for k in expired:
            _sessions.pop(k, None)

