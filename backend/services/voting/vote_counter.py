"""Vote counting.

Decrypts stored votes (using the system AES key) and tallies per candidate.
"""
from backend.config import Config
from backend.models.vote import Vote
from backend.models.candidate import Candidate
from backend.services.cryptography.vote_encryptor import decrypt_vote


def count_votes(election_id: int) -> list:
    """Return sorted results list for an election.

    Each entry: {candidate_id, name, party, symbol, votes}
    """
    votes = Vote.query.filter_by(election_id=election_id).all()
    tally = {}

    for vote in votes:
        try:
            iv = bytes.fromhex(vote.iv)
            plaintext = decrypt_vote(bytes(vote.encrypted_vote), iv, Config.AES_KEY)
            candidate_id = int(plaintext.strip())
        except Exception:
            # Skip votes that cannot be decrypted (integrity issue)
            continue

        tally[candidate_id] = tally.get(candidate_id, 0) + 1

    results = []
    for candidate_id, count in tally.items():
        candidate = Candidate.query.get(candidate_id)
        results.append({
            "candidate_id": candidate_id,
            "name": candidate.name if candidate else f"Candidate #{candidate_id}",
            "party": candidate.party if candidate else None,
            "symbol": candidate.symbol if candidate else None,
            "votes": count,
        })

    results.sort(key=lambda r: r["votes"], reverse=True)
    return results


def total_votes(election_id: int) -> int:
    return Vote.query.filter_by(election_id=election_id).count()

