"""Digital signatures for votes (RSA PKCS#1 v1.5).

Uses persistent keys from `backend/services/cryptography/rsa.py` so that
signatures remain verifiable across server restarts.
"""
from Crypto.Hash import SHA256
from Crypto.Signature import pkcs1_15

from backend.services.cryptography.rsa import PRIVATE_KEY, PUBLIC_KEY


def sign_vote(vote_hash: str) -> str:
    """Sign a hex vote hash, returning a hex signature string."""
    h = SHA256.new(vote_hash.encode("utf-8"))
    signature = pkcs1_15.new(PRIVATE_KEY).sign(h)
    return signature.hex()


def verify_signature(vote_hash: str, signature_hex: str) -> bool:
    """Verify a hex signature over a hex vote hash."""
    try:
        h = SHA256.new(vote_hash.encode("utf-8"))
        signature = bytes.fromhex(signature_hex)
        pkcs1_15.new(PUBLIC_KEY).verify(h, signature)
        return True
    except (ValueError, TypeError):
        return False

