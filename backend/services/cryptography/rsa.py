"""RSA key management with persistence.

Keys are persisted to files so signatures remain valid across restarts.
If no keys exist, a new pair is generated and saved.
"""
import os
from Crypto.PublicKey import RSA

from backend.config import Config


def _ensure_key_dir():
    key_dir = os.path.dirname(Config.RSA_PRIVATE_KEY_PATH)
    os.makedirs(key_dir, exist_ok=True)


def load_or_create_keys():
    """Return (private_key, public_key). Persists generated keys."""
    _ensure_key_dir()

    priv_path = Config.RSA_PRIVATE_KEY_PATH
    pub_path = Config.RSA_PUBLIC_KEY_PATH

    private_key = None
    if os.path.exists(priv_path):
        try:
            with open(priv_path, "r") as f:
                private_key = RSA.import_key(f.read())
        except Exception:
            private_key = None

    if private_key is None:
        private_key = RSA.generate(2048)
        with open(priv_path, "w") as f:
            f.write(private_key.export_key().decode())
        with open(pub_path, "w") as f:
            f.write(private_key.publickey().export_key().decode())

    public_key = None
    if os.path.exists(pub_path):
        try:
            with open(pub_path, "r") as f:
                public_key = RSA.import_key(f.read())
        except Exception:
            public_key = None
    if public_key is None:
        public_key = private_key.publickey()

    return private_key, public_key


# Module-level singletons (loaded once at import time)
PRIVATE_KEY, PUBLIC_KEY = load_or_create_keys()


def sign(data: bytes) -> bytes:
    """Sign raw bytes using RSA PKCS#1 v1.5."""
    from Crypto.Hash import SHA256
    from Crypto.Signature import pkcs1_15
    h = SHA256.new(data)
    return pkcs1_15.new(PRIVATE_KEY).sign(h)


def verify(data: bytes, signature: bytes) -> bool:
    """Verify a signature over raw bytes."""
    from Crypto.Hash import SHA256
    from Crypto.Signature import pkcs1_15
    h = SHA256.new(data)
    try:
        pkcs1_15.new(PUBLIC_KEY).verify(h, signature)
        return True
    except (ValueError, TypeError):
        return False

