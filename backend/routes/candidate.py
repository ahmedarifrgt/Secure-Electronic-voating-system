from flask import Blueprint, request, jsonify

from backend.app import db
from backend.models.candidate import Candidate
from backend.services.security.jwt_manager import decode_jwt_token

bp = Blueprint("candidate", __name__, url_prefix="/candidate")


def _get_payload():
    auth = request.headers.get("Authorization", "")
    token = auth.replace("Bearer ", "") if auth.startswith("Bearer ") else None
    if not token:
        return None
    return decode_jwt_token(token)


def _admin_required(payload):
    return not payload or payload.get("role") != "admin"


@bp.route("/list/<int:election_id>", methods=["GET"])
def list_candidates(election_id):
    """List active candidates for an election."""
    candidates = Candidate.query.filter_by(election_id=election_id, status="Active").all()
    return jsonify({"candidates": [c.to_dict() for c in candidates]})


@bp.route("/add", methods=["POST"])
def add_candidate():
    """Admin-only candidate creation."""
    payload = _get_payload()
    if _admin_required(payload):
        return jsonify({"error": "Admin role required"}), 403

    data = request.json or {}
    required = ["name", "election_id"]
    for field in required:
        if not data.get(field):
            return jsonify({"error": f"{field} is required"}), 400

    candidate = Candidate(
        name=data["name"],
        party=data.get("party"),
        symbol=data.get("symbol"),
        election_id=int(data["election_id"]),
        area_code=data.get("area_code"),
        constituency=data.get("constituency"),
        status=data.get("status", "Active"),
    )
    db.session.add(candidate)
    db.session.commit()

    return jsonify({"message": "Candidate added successfully", "candidate": candidate.to_dict()}), 201

