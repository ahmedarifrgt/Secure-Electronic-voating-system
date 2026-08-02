"""Result publication workflow."""
from backend.models.election import Election
from backend.services.voting.vote_counter import count_votes, total_votes
from backend.services.voting.turnout import calculate_turnout


def publish_results(election_id: int, mark_completed: bool = True) -> dict:
    """Compute and return the published result set for an election."""
    election = Election.query.get(election_id)
    if not election:
        return {"error": "Election not found"}

    results = count_votes(election_id)
    total = total_votes(election_id)
    turnout = calculate_turnout(election_id, total)

    if mark_completed and election.status == "Active":
        election.status = "Completed"
        from backend import db
        db.session.commit()

    return {
        "election_id": election_id,
        "election_name": election.name,
        "total_votes": total,
        "turnout": turnout,
        "results": results,
    }

