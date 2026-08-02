"""Vote validation.

Ensures:
- Voter exists, is active, registered, and eligible.
- Voter has not already voted in the election.
- Election exists and is currently active.
- Candidate belongs to the election and is active.
"""
from datetime import datetime

from backend.models.voter import Voter
from backend.models.election import Election
from backend.models.candidate import Candidate
from backend.models.vote import Vote


def validate_vote(voter_id: int, election_id: int, candidate_id: int) -> dict:
    """Validate a vote request.

    Returns {valid: bool, errors: [..], voter, election, candidate}.
    """
    errors = []

    voter = Voter.query.get(voter_id)
    if not voter:
        errors.append("Voter not found")
    elif voter.account_status != "Active":
        errors.append("Voter account is inactive")
    elif not voter.registration_status:
        errors.append("Voter is not registered")
    elif not voter.eligibility_status:
        errors.append("Voter is not eligible")

    election = Election.query.get(election_id)
    if not election:
        errors.append("Election not found")
    elif election.status != "Active":
        errors.append("Election is not active")
    else:
        now = datetime.now()
        if now < election.start_date:
            errors.append("Election has not started yet")
        if now > election.end_date:
            errors.append("Election has ended")

    candidate = Candidate.query.filter_by(candidate_id=candidate_id, election_id=election_id).first()
    if not candidate:
        errors.append("Candidate not found for this election")
    elif candidate.status != "Active":
        errors.append("Candidate is not active")

    # Duplicate vote check
    if voter and election:
        existing = Vote.query.filter_by(voter_id=voter_id, election_id=election_id).first()
        if existing:
            errors.append("Voter has already voted in this election")

    return {
        "valid": len(errors) == 0,
        "errors": errors,
        "voter": voter,
        "election": election,
        "candidate": candidate,
    }

