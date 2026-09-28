"""Admin voter registration orchestration."""
from datetime import datetime
import logging

from sqlalchemy.exc import IntegrityError

from backend.app import db
from backend.config import Config
from backend.models.voter import Voter
from backend.services.authentication.face_embedding import embedding_to_bytes, generate_embedding
from backend.services.authentication.registered_face_storage import move_registered_face, save_registered_face
from backend.services.authentication.registration_camera import RegistrationCamera, RegistrationCameraError
from backend.services.voter_registration_validator import validate_voter_payload

logger = logging.getLogger(__name__)


class VoterRegistrationError(ValueError):
    def __init__(self, message: str, status_code: int = 400, errors: dict | None = None):
        super().__init__(message)
        self.status_code = status_code
        self.errors = errors or {}


def create_voter_with_camera(data: dict) -> Voter:
    cleaned, errors = validate_voter_payload(data)
    if errors:
        raise VoterRegistrationError("Validation failed", 400, errors)

    replace_image = bool(data.get("replace_existing_image"))
    camera_index = int(data.get("camera_index", 0) or 0)
    image_path = None

    try:
        capture = RegistrationCamera(camera_index=camera_index).capture()
        image_path = save_registered_face(cleaned["nid"], capture.frame, replace_existing=replace_image)
        embedding = generate_embedding(
            image_path,
            model_name=Config.DEEPFACE_MODEL,
            detector_backend=Config.DEEPFACE_DETECTOR,
            strict=True,
        )
        voter = Voter(
            nid=cleaned["nid"],
            full_name=cleaned["full_name"],
            father_name=cleaned["father_name"],
            mother_name=cleaned["mother_name"],
            dob=cleaned["dob"],
            gender=cleaned["gender"],
            mobile=cleaned["mobile"],
            email=cleaned["email"],
            permanent_address=cleaned["permanent_address"],
            present_address=cleaned["present_address"],
            area_code=cleaned["area_code"],
            constituency=cleaned["constituency"],
            face_image_path=image_path,
            face_embedding=embedding_to_bytes(embedding),
            registration_status=cleaned["registration_status"],
            eligibility_status=cleaned["eligibility_status"],
            account_status=cleaned["account_status"],
        )
        db.session.add(voter)
        db.session.commit()
        logger.info("Registered voter %s at %s", voter.nid, image_path)
        return voter
    except FileExistsError as exc:
        db.session.rollback()
        raise VoterRegistrationError(str(exc), 409, {"face_image": str(exc)}) from exc
    except RegistrationCameraError as exc:
        db.session.rollback()
        raise VoterRegistrationError(str(exc), 422, {"camera": str(exc)}) from exc
    except IntegrityError as exc:
        db.session.rollback()
        raise VoterRegistrationError("A voter with this NID already exists.", 409, {"nid": "Duplicate NID."}) from exc
    except Exception as exc:
        db.session.rollback()
        if image_path:
            try:
                import os
                os.remove(image_path)
            except OSError:
                pass
        logger.exception("Voter registration failed for NID %s", cleaned.get("nid"))
        raise VoterRegistrationError(
            f"Voter registration failed due to internal error: {exc}",
            500,
        ) from exc


def registration_success_payload(voter: Voter) -> dict:
    created_at = voter.created_at or datetime.utcnow()
    return {
        "message": "Voter Registered Successfully",
        "voter_id": voter.voter_id,
        "nid": voter.nid,
        "full_name": voter.full_name,
        "saved_image_path": voter.face_image_path,
        "registration_time": created_at.isoformat(),
    }


class VoterUpdateError(ValueError):
    def __init__(self, message: str, status_code: int = 400, errors: dict | None = None):
        super().__init__(message)
        self.status_code = status_code
        self.errors = errors or {}


def update_voter_profile(voter_id: int, data: dict) -> Voter:
    voter = Voter.query.get(voter_id)
    if not voter:
        raise VoterUpdateError("Voter not found.", 404, {"voter_id": "Voter not found."})

    cleaned, errors = validate_voter_payload(data, check_unique=False)
    if errors:
        raise VoterUpdateError("Validation failed", 400, errors)

    existing = Voter.query.filter(Voter.nid == cleaned["nid"], Voter.voter_id != voter_id).first()
    if existing:
        raise VoterUpdateError("A voter with this NID already exists.", 409, {"nid": "Duplicate NID."})

    old_nid = voter.nid
    voter.nid = cleaned["nid"]
    voter.full_name = cleaned["full_name"]
    voter.father_name = cleaned["father_name"]
    voter.mother_name = cleaned["mother_name"]
    voter.dob = cleaned["dob"]
    voter.gender = cleaned["gender"]
    voter.mobile = cleaned["mobile"]
    voter.email = cleaned["email"]
    voter.permanent_address = cleaned["permanent_address"]
    voter.present_address = cleaned["present_address"]
    voter.area_code = cleaned["area_code"]
    voter.constituency = cleaned["constituency"]
    voter.registration_status = cleaned["registration_status"]
    voter.eligibility_status = cleaned["eligibility_status"]
    voter.account_status = cleaned["account_status"]

    if old_nid != voter.nid and voter.face_image_path:
        voter.face_image_path = move_registered_face(old_nid, voter.nid)

    try:
        db.session.commit()
        logger.info("Updated voter %s", voter.voter_id)
        return voter
    except IntegrityError as exc:
        db.session.rollback()
        raise VoterUpdateError("A voter with this NID already exists.", 409, {"nid": "Duplicate NID."}) from exc
    except Exception as exc:
        db.session.rollback()
        logger.exception("Voter update failed for voter_id %s", voter_id)
        raise VoterUpdateError(f"Voter update failed due to internal error: {exc}", 500) from exc
