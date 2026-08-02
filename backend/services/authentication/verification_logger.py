"""Verification logging.

Records each stage of the face-verification pipeline to the `face_logs` table
and suspicious events to `security_logs`, so the admin dashboard can surface
failed verifications and spoof attempts.
"""
from backend import db
from backend.models.face_log import FaceLog
from backend.models.security_log import SecurityLog


def log_face_stage(voter_id=None, nid=None, stage="unknown", status="Skipped",
                   confidence=None, details=None):
    """Insert a face_log row and commit."""
    try:
        entry = FaceLog(
            voter_id=voter_id,
            nid=nid,
            stage=stage,
            status=status,
            confidence=confidence,
            details=str(details) if details else None,
        )
        db.session.add(entry)
        db.session.commit()
        return entry
    except Exception:
        db.session.rollback()
        return None


def log_security_event(event, severity="Info", ip_address=None, details=None):
    """Insert a security_log row and commit."""
    try:
        entry = SecurityLog(
            event=event,
            severity=severity,
            ip_address=ip_address,
            details=str(details) if details else None,
        )
        db.session.add(entry)
        db.session.commit()
        return entry
    except Exception:
        db.session.rollback()
        return None

