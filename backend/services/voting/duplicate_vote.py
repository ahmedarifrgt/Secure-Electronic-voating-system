"""Duplicate vote prevention.

Enforces the one-voter-one-vote-per-election invariant at the DB level
(via the unique constraint on votes(voter_id, election_id)) and at the
application level.
"""
from backend.models.vote import Vote


def has_voted(voter_id: int, election_id: int) -> bool:
    """Return True if the voter has already voted in the election."""
    return Vote.query.filter_by(voter_id=voter_id, election_id=election_id).first() is not None


def count_votes_by_voter(voter_id: int) -> int:
    """Total number of votes cast by a voter (should be <= 1)."""
    return Vote.query.filter_by(voter_id=voter_id).count()

