import base64
import pathlib
import os

from flask import Blueprint, request, jsonify
from werkzeug.security import check_password_hash

from backend.config import Config
from backend.app import db
from backend.models.voter import Voter
from backend.services.authentication.face_verification import verify_face_pipeline
from backend.services.authentication.verification_logger import log_security_event
from backend.services.authentication.face_embedding import bytes_to_embedding, generate_embedding, embedding_to_bytes
from backend.services.authentication._deepface_loader import is_deepface_available
from backend.services.authentication.face_verification_service import run_face_verification
from backend.services.security.jwt_manager import create_jwt_token
from backend.services.security.password_hash import hash_password
from backend.services.security.rate_limiter import is_rate_limited
from backend.services.security.audit_logger import log_audit
from backend.services.voting.turnout import mark_voter_login

bp = Blueprint("auth", __name__, url_prefix="/auth")


def _client_ip():
    return request.headers.get("X-Forwarded-For", request.remote_addr or "unknown")


def _build_verification_payload(result: dict) -> dict:
    """Convert the verify_face_pipeline result into a serializable payload.

    The pipeline stores per-stage tuples ``(stage, passed, details)``; we turn
    those into a list of dicts so the Flutter client can render the breakdown.
    """
    details = result.get("details") or {}
    pipeline = details.get("pipeline") or []
    stages = []
    identity = {}
    for item in pipeline:
        if not isinstance(item, (tuple, list)) or len(item) < 3:
            continue
        stage, passed, stage_details = item[0], item[1], item[2]
        if stage == "identity" and isinstance(stage_details, dict):
            identity = stage_details
        stages.append({
            "stage": stage,
            "passed": bool(passed),
            "details": stage_details if isinstance(stage_details, dict) else {},
        })

    score = result.get("score") or 0.0
    return {
        "passed": bool(result.get("passed")),
        "score": round(float(score), 4),
        "distance": identity.get("distance"),
        "confidence": identity.get("confidence"),
        "model": Config.DEEPFACE_MODEL,
        "detector": Config.DEEPFACE_DETECTOR,
        "distance_metric": Config.DEEPFACE_DISTANCE_METRIC,
        "threshold": Config.FACE_THRESHOLD,
        "stages": stages,
        "mode": details.get("mode"),
        "error": result.get("error"),
    }


@bp.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    ip = _client_ip()

    # --- Admin login ---
    username = data.get("username")
    password = data.get("password")
    if username and password:
        admin_user = Config.ADMIN_USERNAME
        admin_pass = Config.ADMIN_PASSWORD
        admin_hash = Config.ADMIN_PASSWORD_HASH

        if username == admin_user and (
            (admin_hash and check_password_hash(admin_hash, password)) or
            (not admin_hash and password == admin_pass)
        ):
            token = create_jwt_token({"role": "admin", "username": username, "sub": "admin"})
            log_audit("admin", None, "admin_login", details={"username": username}, ip_address=ip)
            return jsonify({
                "message": "Admin login successful",
                "token": token,
                "role": "admin",
            })

        log_security_event("InvalidAdminLogin", "Warning", ip, {"username": username})
        return jsonify({"error": "Invalid admin credentials"}), 401

    # --- Voter login ---
    nid = data.get("nid")
    if not nid:
        return jsonify({"error": "NID is required"}), 400

    # Rate limiting on voter login attempts
    if is_rate_limited(f"login:{nid}:{ip}", limit=5, window_seconds=300):
        log_security_event("RateLimitExceeded", "Warning", ip, {"nid": nid})
        return jsonify({"error": "Too many login attempts. Try again later."}), 429

    voter = Voter.query.filter_by(nid=nid).first()
    if not voter:
        log_security_event("UnknownNidAttempt", "Warning", ip, {"nid": nid})
        return jsonify({"error": "Invalid NID or inactive account"}), 401

    if voter.account_status != "Active":
        return jsonify({"error": "Voter account is inactive"}), 403

    if voter.registration_status is not True:
        return jsonify({"error": "Voter is not registered"}), 403

    if voter.eligibility_status is not True:
        return jsonify({"error": "Voter is not eligible"}), 403

    # Guard: face verification depends on DeepFace + a face detector. If the
    # DeepFace stack is unavailable (e.g. keras/tf-keras mismatch), return a
    # clear 503 instead of blocking or failing with a generic error.
    if not is_deepface_available():
        log_security_event("DeepFaceUnavailable", "Critical", ip, {"nid": nid})
        return jsonify({
            "error": "Face verification service is temporarily unavailable. "
                     "Please contact the administrator.",
        }), 503

    # --- Capture live image (base64) ---
    live_image = data.get("live_image_path")
    live_image_b64 = data.get("live_image_b64")
    live_capture = bool(data.get("live_capture", True))
    extra_frames = data.get("extra_frames") or []

    tmp_paths = []
    if live_image_b64:
        try:
            tmp_dir = pathlib.Path(Config.UPLOAD_FOLDER)
            tmp_dir.mkdir(parents=True, exist_ok=True)
            if live_image_b64.startswith("data:"):
                live_image_b64 = live_image_b64.split(",")[-1]
            img_bytes = base64.b64decode(live_image_b64)
            tmp_path = tmp_dir / f"live_{nid}.jpg"
            with open(tmp_path, "wb") as f:
                f.write(img_bytes)
            live_image = str(tmp_path)
            tmp_paths.append(tmp_path)
        except Exception as e:
            return jsonify({"error": f"Failed to save live image: {e}"}), 400

    saved_extra_frames = []
    for idx, frame_b64 in enumerate(extra_frames or []):
        if not frame_b64:
            continue
        try:
            if isinstance(frame_b64, str) and frame_b64.startswith("data:"):
                frame_b64 = frame_b64.split(",")[-1]
            img_bytes = base64.b64decode(frame_b64)
            tmp_dir = pathlib.Path(Config.UPLOAD_FOLDER)
            tmp_dir.mkdir(parents=True, exist_ok=True)
            tmp_path = tmp_dir / f"live_{nid}_extra_{idx}.jpg"
            with open(tmp_path, "wb") as f:
                f.write(img_bytes)
            saved_extra_frames.append(str(tmp_path))
            tmp_paths.append(tmp_path)
        except Exception as e:
            return jsonify({"error": f"Failed to save extra frame {idx}: {e}"}), 400

    extra_frames = saved_extra_frames

    if not live_image or not os.path.exists(live_image):
        return jsonify({"error": "Live image is required for face verification"}), 400

    # --- Decode stored embedding (if present) ---
    stored_embedding = None
    if voter.face_embedding:
        stored_embedding = bytes_to_embedding(voter.face_embedding)

    # --- Full verification pipeline ---
    try:
        result = verify_face_pipeline(
            registered_image=voter.face_image_path,
            live_image=live_image,
            voter_id=voter.voter_id,
            nid=voter.nid,
            stored_embedding=stored_embedding,
            live_capture=live_capture,
            extra_frames=extra_frames,
            ip_address=ip,
        )
    finally:
        # Keep the temp files until the pipeline has fully completed. The
        # verification call may still need them for embedding generation or any
        # downstream logging step, so only cleanup after the whole request is done.
        for path in tmp_paths:
            try:
                path.unlink()
            except OSError:
                pass

    if not result["passed"]:
        return jsonify({
            "error": result.get("error") or "Face verification failed",
            "verification": _build_verification_payload(result),
        }), 403

    # Optionally update stored embedding if none existed
    if not voter.face_embedding:
        try:
            emb = generate_embedding(
                live_image,
                Config.DEEPFACE_MODEL,
                detector_backend=Config.DEEPFACE_DETECTOR,
                strict=True,
            )
            voter.face_embedding = embedding_to_bytes(emb)
            db.session.commit()
        except Exception:
            db.session.rollback()

    # Mark last_login
    mark_voter_login(voter.voter_id)

    token = create_jwt_token({
        "voter_id": voter.voter_id,
        "nid": voter.nid,
        "role": "voter",
        "sub": str(voter.voter_id),
    })

    log_audit("voter", voter.voter_id, "voter_login", details={"nid": voter.nid}, ip_address=ip)

    return jsonify({
        "message": "Login successful",
        "token": token,
        "role": "voter",
        "voter": voter.to_admin_dict(),
        "verification": _build_verification_payload(result),
    })


@bp.route("/login-popup", methods=["POST"])
def login_popup():
    """Authenticate a voter using the backend host's real OpenCV popup camera.

    This endpoint is intended for a desktop client running on the same machine
    as Flask. The popup is created by ``run_face_verification`` and never uses
    a static image, mock result, or weak embedding fallback.
    """
    data = request.get_json(silent=True) or {}
    nid = str(data.get("nid") or "").strip()
    ip = _client_ip()

    if not nid:
        return jsonify({"error": "NID is required"}), 400

    if is_rate_limited(f"login-popup:{nid}:{ip}", limit=5, window_seconds=300):
        log_security_event("RateLimitExceeded", "Warning", ip, {"nid": nid})
        return jsonify({"error": "Too many login attempts. Try again later."}), 429

    voter = Voter.query.filter_by(nid=nid).first()
    if not voter:
        log_security_event("UnknownNidAttempt", "Warning", ip, {"nid": nid})
        return jsonify({"error": "Invalid NID or inactive account"}), 401
    if voter.account_status != "Active":
        return jsonify({"error": "Voter account is inactive"}), 403
    if voter.registration_status is not True:
        return jsonify({"error": "Voter is not registered"}), 403
    if voter.eligibility_status is not True:
        return jsonify({"error": "Voter is not eligible"}), 403
    if not voter.face_image_path:
        return jsonify({"error": "Registered face image is missing"}), 503
    if not is_deepface_available():
        log_security_event("DeepFaceUnavailable", "Critical", ip, {"nid": nid})
        return jsonify({"error": "Face verification service is unavailable"}), 503

    stored_embedding = bytes_to_embedding(voter.face_embedding) if voter.face_embedding else None
    try:
        result = run_face_verification(
            nid=voter.nid,
            voter_id=voter.voter_id,
            stored_image_path=voter.face_image_path,
            stored_embedding=stored_embedding,
            ip_address=ip,
            camera_index=int(data.get("camera_index", 0) or 0),
        )
    except (TypeError, ValueError) as exc:
        return jsonify({"error": f"Invalid popup verification request: {exc}"}), 400

    if not result.get("passed"):
        return jsonify({
            "error": result.get("error") or "Face verification failed",
            "verification": _build_verification_payload(result),
        }), 403

    mark_voter_login(voter.voter_id)
    token = create_jwt_token({
        "voter_id": voter.voter_id,
        "nid": voter.nid,
        "role": "voter",
        "sub": str(voter.voter_id),
    })
    log_audit("voter", voter.voter_id, "voter_login_popup", details={"nid": nid}, ip_address=ip)

    return jsonify({
        "message": "Login successful",
        "token": token,
        "role": "voter",
        "voter": voter.to_admin_dict(),
        "verification": _build_verification_payload(result),
    })


@bp.route("/voter/<int:voter_id>", methods=["GET"])
def get_voter(voter_id):
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "") if auth_header.startswith("Bearer ") else None
    if not token:
        return jsonify({"error": "Missing token"}), 401
    from backend.services.security.jwt_manager import decode_jwt_token
    payload = decode_jwt_token(token)
    if not payload:
        return jsonify({"error": "Invalid or expired token"}), 401
    if payload.get("role") not in ("admin", "voter"):
        return jsonify({"error": "Unauthorized"}), 403
    if payload.get("role") != "admin" and payload.get("voter_id") != voter_id:
        return jsonify({"error": "Forbidden"}), 403

    voter = Voter.query.get(voter_id)
    if not voter:
        return jsonify({"error": "Voter not found"}), 404

    response = voter.to_admin_dict() if payload.get("role") == "admin" else voter.to_public_dict()
    return jsonify({"voter": response})


@bp.route("/voter/me", methods=["GET"])
def voter_me():
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "") if auth_header.startswith("Bearer ") else None
    if not token:
        return jsonify({"error": "Missing token"}), 401
    from backend.services.security.jwt_manager import decode_jwt_token
    payload = decode_jwt_token(token)
    if not payload:
        return jsonify({"error": "Invalid or expired token"}), 401
    voter = Voter.query.get(payload.get("voter_id"))
    if not voter:
        return jsonify({"error": "Voter not found"}), 404
    return jsonify({"voter": voter.to_admin_dict()})
