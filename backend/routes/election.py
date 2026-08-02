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

    # Determine initial status: if the provided status is not Active but the
    # start/end window contains the current time, treat the election as Active.
    from datetime import datetime
    now = datetime.now()
    requested_status = data.get("status", "Upcoming")
    status = requested_status
    if requested_status != "Active" and start <= now <= end:
        status = "Active"

    election = Election(
        name=data["name"],
        description=data.get("description"),
        area_code=data.get("area_code"),
        constituency=data.get("constituency"),
        start_date=start,
        end_date=end,
        status=status,
    )
    db.session.add(election)
    db.session.commit()

    return jsonify({"message": "Election created successfully", "election": election.to_dict()}), 201


@bp.route('/publish/<int:election_id>', methods=['POST'])
def publish_election(election_id):
    """Admin-only: set an election to Active immediately."""
    payload = _get_payload()
    if _admin_required(payload):
        return jsonify({"error": "Admin role required"}), 403

    election = Election.query.get(election_id)
    if not election:
        return jsonify({"error": "Election not found"}), 404

    election.status = 'Active'
    from backend.app import db
    db.session.add(election)
    db.session.commit()

    return jsonify({"message": "Election published", "election": election.to_dict()})


@bp.route('/<int:election_id>/voters', methods=['GET'])
def election_voters(election_id):
    """Admin-only: list voters that match the election's area_code or constituency.

    Optional query param `q` to search by name, nid, or voter_id.
    """
    payload = _get_payload()
    if _admin_required(payload):
        return jsonify({"error": "Admin role required"}), 403

    election = Election.query.get(election_id)
    if not election:
        return jsonify({"error": "Election not found"}), 404

    from backend.models.voter import Voter
    from sqlalchemy import or_

    q_param = (request.args.get('q') or '').strip()
    q = Voter.query.filter_by(account_status='Active')

    # Prefer voters in the same constituency; fallback to area_code match.
    if election.constituency:
        q = q.filter(or_(Voter.constituency == election.constituency,
                         Voter.area_code == election.area_code))
    elif election.area_code:
        q = q.filter(Voter.area_code == election.area_code)

    # Only include registered & eligible voters by default
    q = q.filter(Voter.registration_status == True, Voter.eligibility_status == True)

    if q_param:
        search_int = int(q_param) if q_param.isdigit() else None
        filters = [
            Voter.full_name.ilike(f"%{q_param}%"),
            Voter.nid.like(f"%{q_param}%"),
        ]
        if search_int is not None:
            filters.append(Voter.voter_id == search_int)
        q = q.filter(or_(*filters))

    voters = q.order_by(Voter.voter_id.desc()).limit(1000).all()
    return jsonify({"voters": [v.to_public_dict() for v in voters]})


@bp.route('/<int:election_id>/notify', methods=['POST'])
def notify_election_voters(election_id):
    """Admin-only: create audit log entries to mark notification for voters of this election.

    This is a simple server-side marker; actual delivery (email/push) should be
    implemented by integrating an external service. Request body can include
    `message` to include in the audit details.
    """
    payload = _get_payload()
    if _admin_required(payload):
        return jsonify({"error": "Admin role required"}), 403

    election = Election.query.get(election_id)
    if not election:
        return jsonify({"error": "Election not found"}), 404

    data = request.json or {}
    message = data.get('message')

    from backend.models.voter import Voter
    from backend.models.audit_log import AuditLog

    q = Voter.query.filter_by(account_status='Active', registration_status=True, eligibility_status=True)
    if election.constituency:
        q = q.filter((Voter.constituency == election.constituency) | (Voter.area_code == election.area_code))
    elif election.area_code:
        q = q.filter(Voter.area_code == election.area_code)

    voters = q.all()
    created = 0
    for v in voters:
        log = AuditLog(
            actor_type='system',
            actor_id=None,
            action='ElectionNotify',
            details=f"Election {election.election_id} notify -> voter {v.voter_id}: {message}",
            ip_address=None,
        )
        from backend.app import db
        db.session.add(log)
        created += 1
    db.session.commit()

    return jsonify({"message": "Notifications queued (audit logs created)", "notified": created})

