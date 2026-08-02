"""Vote integrity checking.

Verifies that a stored vote:
1. Decrypts correctly with AES-256.
2. Its SHA-256 hash matches the plaintext.
3. Its RSA signature is valid.
"""
from backend.config import Config
from backend.services.cryptography.vote_encryptor import decrypt_vote, hash_vote
from backend.services.cryptography.signature import verify_signature


def check_vote_integrity(vote, aes_key: str = None) -> dict:
    """Run full integrity checks on a Vote model instance.

    Returns dict {valid, reasons[], decrypted_candidate, details}.
    """
    aes_key = aes_key or Config.AES_KEY
    reasons = []
    details = {}

    # 1. Decrypt
    try:
        iv = bytes.fromhex(vote.iv)
        plaintext = decrypt_vote(bytes(vote.encrypted_vote), iv, aes_key)
        details["decrypted"] = plaintext
    except Exception as e:
        return {"valid": False, "reasons": [f"Decryption failed: {e}"],
                "decrypted_candidate": None, "details": details}

    # 2. Hash check
    computed_hash = hash_vote(plaintext)
    details["computed_hash"] = computed_hash
    details["stored_hash"] = vote.hash
    if computed_hash != vote.hash:
        reasons.append("Hash mismatch — vote data was modified")

    # 3. Signature check
    try:
        sig_valid = verify_signature(vote.hash, vote.signature)
        details["signature_valid"] = sig_valid
        if not sig_valid:
            reasons.append("Signature invalid — vote was not signed by the system")
    except Exception as e:
        reasons.append(f"Signature check error: {e}")

    return {
        "valid": len(reasons) == 0,
        "reasons": reasons,
        "decrypted_candidate": plaintext if not reasons else None,
        "details": details,
    }

