from flask import Blueprint, request, jsonify

from backend.app import db
from backend.models.election import Election
from backend.services.security.jwt_manager import decode_jwt_token

bp = Blueprint("election", __name__, url_prefix="/election")


def _admin_required(payload):
    if not payload or payload.get("role") != "admin":
        return True
    return False


def _get_payload():
    auth = request.headers.get("Authorization", "")
    token = auth.replace("Bearer ", "") if auth.startswith("Bearer ") else None
    if not token:
        return None
    return decode_jwt_token(token)


@bp.route("/list", methods=["GET"])
def list_elections():
    """List elections; optionally filter by status."""
    status = request.args.get("status")
    q = Election.query
    if status:
        q = q.filter_by(status=status)
    elections = q.order_by(Election.start_date).all()
    return jsonify({"elections": [e.to_dict() for e in elections]})


@bp.route("/eligible/<int:voter_id>", methods=["GET"])
def eligible_elections(voter_id):
    """Return elections the voter can participate in (active + not voted)."""
    from backend.models.voter import Voter
    from backend.models.vote import Vote

    voter = Voter.query.get(voter_id)
    if not voter:
        return jsonify({"error": "Voter not found"}), 404
    if not voter.eligibility_status:
        return jsonify({"error": "Voter is not eligible"}), 403

    from datetime import datetime
    now = datetime.now()

    # Match voter's area/constituency where possible
    q = Election.query.filter_by(status="Active")
    if voter.constituency:
        q = q.filter((Election.constituency == voter.constituency) |
                     (Election.constituency.is_(None)))
    if voter.area_code:
        q = q.filter((Election.area_code == voter.area_code) |
                     (Election.area_code.is_(None)))

    elections = q.filter(Election.start_date <= now, Election.end_date >= now).all()

    # Exclude elections the voter already voted in
    voted_ids = {v.election_id for v in Vote.query.filter_by(voter_id=voter_id).all()}
    result = [e.to_dict() for e in elections if e.election_id not in voted_ids]
    return jsonify({"elections": result})


@bp.route("/create", methods=["POST"])
def create_election():
    """Admin-only election creation."""
    payload = _get_payload()
    if _admin_required(payload):
        return jsonify({"error": "Admin role required"}), 403

    data = request.json or {}
    required = ["name", "start_date", "end_date"]
    for field in required:
        if not data.get(field):
            return jsonify({"error": f"{field} is required"}), 400

    from datetime import datetime
    try:
        start = datetime.fromisoformat(data["start_date"])
        end = datetime.fromisoformat(data["end_date"])
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid date format (use ISO 8601)"}), 400

    if end <= start:
        return jsonify({"error": "end_date must be after start_date"}), 400

    election = Election(
        name=data["name"],
        description=data.get("description"),
        area_code=data.get("area_code"),
        constituency=data.get("constituency"),
        start_date=start,
        end_date=end,
        status=data.get("status", "Upcoming"),
    )
    db.session.add(election)
    db.session.commit()

    return jsonify({"message": "Election created successfully", "election": election.to_dict()}), 201

