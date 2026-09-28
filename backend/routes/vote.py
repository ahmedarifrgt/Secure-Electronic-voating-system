import os
import base64

from flask import Blueprint, request, jsonify
from sqlalchemy.exc import IntegrityError

from backend.app import db
from backend.models.vote import Vote
from backend.models.voter import Voter
from backend.services.cryptography.vote_encryptor import encrypt_vote, hash_vote
from backend.services.cryptography.signature import sign_vote
from backend.services.voting.vote_validator import validate_vote
from backend.services.voting.duplicate_vote import has_voted
from backend.services.security.jwt_manager import decode_jwt_token
from backend.services.security.audit_logger import log_audit
from backend.services.security.sql_guard import contains_sql_injection
from backend.services.security.xss import contains_xss

bp = Blueprint("vote", __name__, url_prefix="/vote")


def _client_ip():
    return request.headers.get("X-Forwarded-For", request.remote_addr or "unknown")


def _require_voter_auth():
    """Extract and validate voter JWT from Authorization header.

    Returns (payload, error_response) — one of which is None.
    """
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "") if auth_header.startswith("Bearer ") else None
    if not token:
        return None, (jsonify({"error": "Missing Authorization token"}), 401)
    payload = decode_jwt_token(token)
    if not payload:
        return None, (jsonify({"error": "Invalid or expired token"}), 401)
    if payload.get("role") != "voter":
        return None, (jsonify({"error": "Voter role required"}), 403)
    return payload, None


@bp.route("/cast", methods=["POST"])
def cast_vote():
    """Full secure vote-casting workflow."""
    data = request.json or {}
    ip = _client_ip()

    # --- Auth ---
    payload, err = _require_voter_auth()
    if err:
        return err

    voter_id = payload.get("voter_id")
    election_id = data.get("election_id")
    candidate_id = data.get("candidate_id")

    if not election_id or not candidate_id:
        return jsonify({"error": "election_id and candidate_id are required"}), 400

    # --- Input validation (SQLi / XSS) ---
    if contains_sql_injection(str(election_id)) or contains_sql_injection(str(candidate_id)):
        return jsonify({"error": "Invalid input"}), 400

    # --- Validate vote (eligibility, election active, candidate, duplicate) ---
    validation = validate_vote(voter_id, int(election_id), int(candidate_id))
    if not validation["valid"]:
        return jsonify({"error": "; ".join(validation["errors"])}), 400

    # --- Generate vote token ---
    token = os.urandom(32).hex()

    # --- AES-256 encrypt vote ---
    encrypted_vote, iv = encrypt_vote(str(candidate_id))

    # --- SHA-256 hash generation ---
    vote_hash = hash_vote(str(candidate_id))

    # --- RSA digital signature ---
    signature = sign_vote(vote_hash)

    # --- Store secure vote ---
    vote = Vote(
        election_id=int(election_id),
        voter_id=voter_id,
        candidate_id=int(candidate_id),
        encrypted_vote=encrypted_vote,
        hash=vote_hash,
        signature=signature,
        iv=iv.hex(),
        token=token,
    )

    try:
        voter = db.session.get(Voter, voter_id)
        if voter:
            voter.has_voted = True
        db.session.add(vote)
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify({"error": "Voter has already voted in this election"}), 409
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"Failed to cast vote: {exc}"}), 500

    # --- Create audit log ---
    log_audit("voter", voter_id, "cast_vote",
              details={"election_id": election_id, "candidate_id": candidate_id,
                       "token": token},
              ip_address=ip)

    return jsonify({
        "message": "Vote successfully cast",
        "token": token,
        "vote_id": vote.vote_id,
    }), 201


@bp.route("/status", methods=["GET"])
def vote_status():
    """Check whether the authenticated voter has already voted in an election."""
    payload, err = _require_voter_auth()
    if err:
        return err

    voter_id = payload.get("voter_id")
    election_id = request.args.get("election_id", type=int)
    if not election_id:
        return jsonify({"error": "election_id query param is required"}), 400

    voted = has_voted(voter_id, election_id)
    return jsonify({"voter_id": voter_id, "election_id": election_id, "has_voted": voted})

