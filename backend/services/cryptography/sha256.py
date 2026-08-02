"""SHA-256 hashing utilities."""
import hashlib


def sha256(data) -> str:
    """Return hex digest of str or bytes."""
    if isinstance(data, str):
        data = data.encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def sha256_bytes(data) -> bytes:
    """Return raw 32-byte digest."""
    if isinstance(data, str):
        data = data.encode("utf-8")
    return hashlib.sha256(data).digest()


def double_sha256(data) -> str:
    """SHA-256 of SHA-256 (for extra protection)."""
    return sha256(sha256(data))

