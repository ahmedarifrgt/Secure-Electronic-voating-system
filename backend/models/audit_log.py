from backend import db


class AuditLog(db.Model):
    __tablename__ = 'audit_logs'

    audit_id = db.Column(db.Integer, primary_key=True)
    actor_type = db.Column(db.Enum('voter', 'admin', 'system'), default='system')
    actor_id = db.Column(db.Integer)
    action = db.Column(db.String(100), nullable=False)
    details = db.Column(db.Text)
    ip_address = db.Column(db.String(45))
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    def to_dict(self):
        return {
            'audit_id': self.audit_id,
            'actor_type': self.actor_type,
            'actor_id': self.actor_id,
            'action': self.action,
            'details': self.details,
            'ip_address': self.ip_address,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f"<AuditLog {self.audit_id} {self.action}>"

