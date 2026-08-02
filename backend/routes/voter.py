from flask import Blueprint, jsonify, request
from sqlalchemy import or_

from backend.models.voter import Voter
from backend.services.security.jwt_manager import decode_jwt_token

bp = Blueprint("voter", __name__, url_prefix="/voter")


def _require_admin():
    auth = request.headers.get("Authorization", "")
    token = auth.replace("Bearer ", "") if auth.startswith("Bearer ") else None
    if not token:
        return None, (jsonify({"error": "Missing token"}), 401)
    payload = decode_jwt_token(token)
    if not payload:
        return None, (jsonify({"error": "Invalid or expired token"}), 401)
    if payload.get("role") != "admin":
        return None, (jsonify({"error": "Admin role required"}), 403)
    return payload, None


@bp.route('/list', methods=['GET'])
def list_voters():
    """Admin-only: list voters with optional eligibility filter."""
    payload, err = _require_admin()
    if err:
        return err

    eligible_only = request.args.get("eligible", "false").lower() == "true"
    search = (request.args.get("q") or "").strip()
    q = Voter.query
    if eligible_only:
        q = q.filter_by(eligibility_status=True, account_status="Active")

    if search:
        search_int = int(search) if search.isdigit() else None
        search_filters = [
            Voter.full_name.ilike(f"%{search}%"),
            Voter.nid.like(f"%{search}%"),
        ]
        if search_int is not None:
            search_filters.append(Voter.voter_id == search_int)
        q = q.filter(or_(*search_filters))

    voters = q.order_by(Voter.voter_id.desc()).limit(200).all()
    return jsonify({
        "voters": [v.to_public_dict() for v in voters]
    })


@bp.route('/detail/<int:voter_id>', methods=['GET'])
def get_voter_detail(voter_id):
    payload, err = _require_admin()
    if err:
        return err

    voter = Voter.query.get(voter_id)
    if not voter:
        return jsonify({"error": "Voter not found"}), 404

    return jsonify({"voter": voter.to_public_dict()})

