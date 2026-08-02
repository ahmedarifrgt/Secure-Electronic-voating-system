from flask import Blueprint, jsonify

from backend.services.security.jwt_manager import decode_jwt_token
from backend.services.reports.analytics import dashboard_stats
from flask import request

bp = Blueprint("dashboard", __name__, url_prefix="/dashboard")


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


@bp.route("/stats", methods=["GET"])
def stats():
    """Admin-only dashboard statistics."""
    payload, err = _require_admin()
    if err:
        return err
    return jsonify(dashboard_stats())


@bp.route("/public", methods=["GET"])
def public_stats():
    """Public read-only summary (no sensitive details)."""
    data = dashboard_stats()
    return jsonify({
        "total_voters": data["total_voters"],
        "active_voters": data["active_voters"],
        "ongoing_elections": data["ongoing_elections"],
        "votes_cast": data["votes_cast"],
        "turnout_percentage": data["turnout_percentage"],
    })

