"""Audit logging for sensitive actions (login, vote, publish, admin ops)."""
from backend import db
from backend.models.audit_log import AuditLog


def log_audit(actor_type: str = "system", actor_id=None, action: str = "",
              details=None, ip_address: str = None):
    """Create and commit an audit log entry."""
    try:
        entry = AuditLog(
            actor_type=actor_type if actor_type in ("voter", "admin", "system") else "system",
            actor_id=actor_id,
            action=action,
            details=str(details) if details else None,
            ip_address=ip_address,
        )
        db.session.add(entry)
        db.session.commit()
        return entry
    except Exception:
        db.session.rollback()
        return None

