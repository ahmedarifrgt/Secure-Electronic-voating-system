import re

from flask import Blueprint, request, jsonify

from backend.app import db
from backend.models.vote import Vote
from backend.services.cryptography.integrity_checker import check_vote_integrity
from backend.services.voting.vote_counter import count_votes, total_votes
from backend.services.voting.publish_result import publish_results
from backend.services.security.jwt_manager import decode_jwt_token
from backend.services.security.audit_logger import log_audit

bp = Blueprint("report", __name__, url_prefix="/report")


def _client_ip():
    return request.headers.get("X-Forwarded-For", request.remote_addr or "unknown")


def _require_admin():
    """Return (payload, error_response)."""
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


@bp.route("/verify", methods=["GET"])
def verify_votes():
    """Admin integrity verification of all stored votes."""
    payload, err = _require_admin()
    if err:
        return err

    votes = Vote.query.all()
    verified_count = 0
    failed = []
    for vote in votes:
        result = check_vote_integrity(vote)
        if result["valid"]:
            verified_count += 1
            if not vote.is_verified:
                vote.is_verified = True
        else:
            failed.append({"vote_id": vote.vote_id, "reasons": result["reasons"]})

    db.session.commit()
    log_audit("admin", None, "verify_integrity",
              details={"total": len(votes), "verified": verified_count, "failed": len(failed)},
              ip_address=_client_ip())

    return jsonify({
        "total_votes": len(votes),
        "verified_votes": verified_count,
        "failed_votes": len(failed),
        "failed_details": failed,
    })


@bp.route("/verify-token", methods=["POST"])
def verify_vote_token():
    """Admin verification for a single vote receipt token.

    The token is the anonymous receipt shown to the voter after casting.
    This endpoint resolves the token to the stored vote and checks the vote
    integrity so admins can confirm a receipt without exposing voter identity
    in the UI.
    """
    payload, err = _require_admin()
    if err:
        return err

    data = request.json or {}
    token = str(data.get("token") or "").strip()
    if not token:
        return jsonify({"error": "token is required"}), 400
    if not re.fullmatch(r"[0-9a-fA-F]{64}", token):
        return jsonify({"error": "Invalid token format"}), 400

    vote = Vote.query.filter_by(token=token).first()
    if not vote:
        log_audit(
            "admin",
            None,
            "verify_vote_token",
            details={"token": token, "found": False},
            ip_address=_client_ip(),
        )
        return jsonify({
            "found": False,
            "valid": False,
            "token": token,
            "message": "No vote found for this token",
        })

    integrity = check_vote_integrity(vote)
    if integrity["valid"] and not vote.is_verified:
        vote.is_verified = True
        db.session.commit()
    elif not integrity["valid"] and vote.is_verified:
        vote.is_verified = False
        db.session.commit()

    log_audit(
        "admin",
        None,
        "verify_vote_token",
        details={
            "token": token,
            "found": True,
            "vote_id": vote.vote_id,
            "election_id": vote.election_id,
            "valid": integrity["valid"],
        },
        ip_address=_client_ip(),
    )

    return jsonify({
        "found": True,
        "valid": integrity["valid"],
        "token": vote.token,
        "vote_id": vote.vote_id,
        "election_id": vote.election_id,
        "candidate_id": vote.candidate_id,
        "voter_id": vote.voter_id,
        "timestamp": vote.timestamp.isoformat() if vote.timestamp else None,
        "is_verified": vote.is_verified,
        "reasons": integrity.get("reasons", []),
    })


@bp.route("/publish/<int:election_id>", methods=["GET", "POST"])
def publish(election_id):
    """Admin publish of election results (with integrity verification)."""
    payload, err = _require_admin()
    if err:
        return err

    # Verify all votes for this election first
    votes = Vote.query.filter_by(election_id=election_id).all()
    verified_count = 0
    for vote in votes:
        if check_vote_integrity(vote)["valid"]:
            verified_count += 1
        else:
            vote.is_verified = False

    db.session.commit()

    result = publish_results(election_id)
    if "error" in result:
        return jsonify(result), 404

    result["verified_votes"] = verified_count
    result["integrity_status"] = "PASS" if verified_count == len(votes) else "PARTIAL"

    log_audit("admin", None, "publish_results",
              details={"election_id": election_id, "total": len(votes), "verified": verified_count},
              ip_address=_client_ip())

    return jsonify(result)


@bp.route("/results/<int:election_id>", methods=["GET"])
def get_results(election_id):
    """Public results view (no integrity details exposed)."""
    election_name = None
    from backend.models.election import Election
    election = Election.query.get(election_id)
    if election:
        election_name = election.name

    results = count_votes(election_id)
    total = total_votes(election_id)
    return jsonify({
        "election_id": election_id,
        "election_name": election_name,
        "total_votes": total,
        "results": results,
    })

