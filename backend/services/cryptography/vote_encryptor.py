"""High-level vote encryption, hashing, and signing helpers."""
from backend.config import Config
from backend.services.cryptography.aes256 import encrypt, decrypt
from backend.services.cryptography.sha256 import sha256
from backend.services.cryptography.signature import sign_vote, verify_signature


def encrypt_vote(vote_data: str, key: str = None):
    """Encrypt vote data with AES-256-CBC.

    Returns (ciphertext_bytes, iv_bytes).
    """
    aes_key = key or Config.AES_KEY
    return encrypt(vote_data, aes_key)


def decrypt_vote(ciphertext: bytes, iv, key: str = None) -> str:
    """Decrypt vote data."""
    aes_key = key or Config.AES_KEY
    plaintext = decrypt(ciphertext, aes_key, iv)
    return plaintext.decode("utf-8")


def hash_vote(vote_data: str) -> str:
    """SHA-256 hash of vote data."""
    return sha256(vote_data)


def sign_vote_hash(vote_hash: str) -> str:
    """RSA-sign a vote hash."""
    return sign_vote(vote_hash)


def verify_vote_signature(vote_hash: str, signature_hex: str) -> bool:
    return verify_signature(vote_hash, signature_hex)

