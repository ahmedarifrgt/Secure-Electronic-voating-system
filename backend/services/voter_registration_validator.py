"""Validation for admin-created voter registrations."""
from datetime import date, datetime
import re

from backend.models.voter import Voter

EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
MOBILE_RE = re.compile(r"^(?:\+?88)?01[3-9]\d{8}$")
REQUIRED_FIELDS = ("nid", "full_name", "dob")
GENDERS = {"Male", "Female", "Other", None, ""}
ACCOUNT_STATUSES = {"Active", "Inactive", None, ""}


def validate_voter_payload(data: dict, check_unique: bool = True) -> tuple[dict, dict]:
    errors = {}
    cleaned = {}

    for field in REQUIRED_FIELDS:
        value = _string(data.get(field))
        if not value:
            errors[field] = "This field is required."
        cleaned[field] = value

    nid = cleaned.get("nid", "")
    if nid and (not nid.isdigit() or len(nid) > 20):
        errors["nid"] = "NID must contain digits only and be at most 20 characters."
    elif check_unique and nid and Voter.query.filter_by(nid=nid).first():
        errors["nid"] = "A voter with this NID already exists."

    for field in (
        "full_name", "father_name", "mother_name", "mobile", "email",
        "permanent_address", "present_address", "area_code", "constituency",
    ):
        cleaned[field] = _string(data.get(field))

    if cleaned["full_name"] and len(cleaned["full_name"]) > 100:
        errors["full_name"] = "Full name must be at most 100 characters."

    for field in ("father_name", "mother_name"):
        if cleaned[field] and len(cleaned[field]) > 100:
            errors[field] = "Name must be at most 100 characters."

    if cleaned["mobile"] and not MOBILE_RE.match(cleaned["mobile"]):
        errors["mobile"] = "Enter a valid Bangladeshi mobile number."

    if cleaned["email"] and (len(cleaned["email"]) > 100 or not EMAIL_RE.match(cleaned["email"])):
        errors["email"] = "Enter a valid email address."

    if cleaned["area_code"] and len(cleaned["area_code"]) > 10:
        errors["area_code"] = "Area code must be at most 10 characters."

    if cleaned["constituency"] and len(cleaned["constituency"]) > 50:
        errors["constituency"] = "Constituency must be at most 50 characters."

    cleaned["dob"] = _parse_date(data.get("dob"), errors)
    cleaned["gender"] = _enum(data.get("gender"), GENDERS, "gender", errors)
    cleaned["account_status"] = _enum(data.get("account_status"), ACCOUNT_STATUSES, "account_status", errors) or "Active"
    cleaned["registration_status"] = _bool(data.get("registration_status"), False)
    cleaned["eligibility_status"] = _bool(data.get("eligibility_status"), False)

    return cleaned, errors


def _string(value) -> str:
    return str(value).strip() if value is not None else ""


def _parse_date(value, errors: dict):
    if isinstance(value, date):
        parsed = value
    else:
        try:
            parsed = datetime.strptime(_string(value), "%Y-%m-%d").date()
        except ValueError:
            errors["dob"] = "Date of birth must use YYYY-MM-DD format."
            return None
    if parsed >= date.today():
        errors["dob"] = "Date of birth must be in the past."
    return parsed


def _enum(value, allowed: set, field: str, errors: dict):
    cleaned = _string(value)
    if cleaned not in allowed:
        errors[field] = f"Invalid {field.replace('_', ' ')}."
    return cleaned or None


def _bool(value, default: bool) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    return str(value).strip().lower() in {"1", "true", "yes", "on"}
