"""HTTP controller for admin voter registration."""
from flask import jsonify, request

from backend.services.voter_registration_service import (
    VoterRegistrationError,
    create_voter_with_camera,
    update_voter_profile,
    VoterUpdateError,
    registration_success_payload,
)


def create_voter_response():
    data = request.get_json(silent=True) or {}
    try:
        voter = create_voter_with_camera(data)
    except VoterRegistrationError as exc:
        body = {"error": str(exc)}
        if exc.errors:
            body["validation"] = exc.errors
        # Structured flag so the Flutter client can prompt the administrator
        # to replace an existing face image instead of showing a generic error.
        if exc.status_code == 409 and "face_image" in exc.errors:
            body["duplicate_image"] = True
            body["message"] = "A registered face image already exists for this NID. Replace it?"
        return jsonify(body), exc.status_code
    except Exception as exc:
        return jsonify({
            "error": "Voter registration failed. Please try again or contact support.",
            "details": str(exc),
        }), 500

    return jsonify({
        "success": True,
        "result": registration_success_payload(voter),
        "voter": voter.to_admin_dict(),
        "actions": ["Register Another Voter", "Close"],
    }), 201


def update_voter_response(voter_id: int):
    data = request.get_json(silent=True) or {}
    try:
        voter = update_voter_profile(voter_id, data)
    except VoterUpdateError as exc:
        body = {"error": str(exc)}
        if exc.errors:
            body["validation"] = exc.errors
        return jsonify(body), exc.status_code
    except Exception as exc:
        return jsonify({
            "error": "Voter update failed. Please try again or contact support.",
            "details": str(exc),
        }), 500

    return jsonify({
        "success": True,
        "voter": voter.to_admin_dict(),
        "message": "Voter updated successfully.",
    })
