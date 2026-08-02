"""In-memory sliding-window rate limiter.

Tracks request counts per key in memory. Suitable for single-process dev;
for multi-worker production, swap this for Redis.
"""
import time
import threading
from collections import defaultdict, deque

_requests = defaultdict(deque)
_lock = threading.Lock()
_window = 300  # seconds
_max_entries = 10000


def _cleanup(now: float):
    """Drop stale entries and trim memory."""
    if len(_requests) > _max_entries:
        for key in list(_requests.keys()):
            if not _requests[key]:
                del _requests[key]


def is_rate_limited(key: str, limit: int = 5, window_seconds: int = 300) -> bool:
    """Return True if `key` has exceeded `limit` requests in the window."""
    now = time.time()
    with _lock:
        dq = _requests[key]
        # Drop entries older than the window
        while dq and dq[0] < now - window_seconds:
            dq.popleft()
        if len(dq) >= limit:
            return True
        dq.append(now)
        _cleanup(now)
        return False


def get_remaining(key: str, limit: int = 5, window_seconds: int = 300) -> int:
    """Return how many requests remain for the key."""
    now = time.time()
    with _lock:
        dq = _requests[key]
        while dq and dq[0] < now - window_seconds:
            dq.popleft()
        return max(0, limit - len(dq))


def reset(key: str):
    with _lock:
        _requests.pop(key, None)

