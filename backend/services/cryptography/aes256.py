"""AES-256 encryption utilities (CBC mode with PKCS7 padding)."""
import os
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

# AES-256 requires a 32-byte key
KEY_LENGTH = 32
IV_LENGTH = 16


def _normalize_key(key) -> bytes:
    """Ensure the key is exactly 32 bytes (hash if too short/long)."""
    if isinstance(key, str):
        key = key.encode("utf-8")
    if len(key) != KEY_LENGTH:
        import hashlib
        key = hashlib.sha256(key).digest()
    return key


def encrypt(plaintext, key) -> tuple:
    """Encrypt plaintext (str or bytes) with AES-256-CBC.

    Returns (ciphertext_bytes, iv_bytes).
    """
    if isinstance(plaintext, str):
        plaintext = plaintext.encode("utf-8")
    aes_key = _normalize_key(key)
    iv = os.urandom(IV_LENGTH)
    cipher = AES.new(aes_key, AES.MODE_CBC, iv)
    ciphertext = cipher.encrypt(pad(plaintext, AES.block_size))
    return ciphertext, iv


def decrypt(ciphertext: bytes, key, iv: bytes) -> bytes:
    """Decrypt AES-256-CBC ciphertext."""
    aes_key = _normalize_key(key)
    cipher = AES.new(aes_key, AES.MODE_CBC, iv)
    plaintext = unpad(cipher.decrypt(ciphertext), AES.block_size)
    return plaintext


def encrypt_hex(plaintext, key) -> str:
    """Encrypt and return (ciphertext.hex(), iv.hex()) as tuple."""
    ct, iv = encrypt(plaintext, key)
    return ct.hex(), iv.hex()


def decrypt_hex(ciphertext_hex: str, key, iv_hex: str) -> bytes:
    ct = bytes.fromhex(ciphertext_hex)
    iv = bytes.fromhex(iv_hex)
    return decrypt(ct, key, iv)

