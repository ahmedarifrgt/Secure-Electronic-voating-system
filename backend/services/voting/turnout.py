"""Voter turnout utilities."""
from datetime import datetime

from backend import db
from backend.models.voter import Voter


def mark_voter_login(voter_id: int):
    """Update last_login timestamp."""
    try:
        voter = db.session.get(Voter, voter_id)
        if voter:
            voter.last_login = datetime.now()
            db.session.commit()
    except Exception:
        db.session.rollback()


def calculate_turnout(election_id: int, votes_cast: int = None, constituency: str = None) -> dict:
    """Compute turnout for an election or constituency."""
    from backend.models.vote import Vote
    from backend.models.voter import Voter

    try:
        if votes_cast is None:
            votes_cast = Vote.query.filter_by(election_id=election_id).count()

        voter_query = Voter.query.filter_by(eligibility_status=True)
        if constituency:
            voter_query = voter_query.filter_by(constituency=constituency)
        total_eligible = voter_query.count()

        turnout = (votes_cast / total_eligible * 100) if total_eligible > 0 else 0.0
        return {
            "election_id": election_id,
            "votes_cast": votes_cast,
            "total_eligible": total_eligible,
            "turnout_percentage": round(turnout, 2),
        }
    except Exception:
        return {
            "election_id": election_id,
            "votes_cast": votes_cast or 0,
            "total_eligible": 0,
            "turnout_percentage": 0.0,
        }

