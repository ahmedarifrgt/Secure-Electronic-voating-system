from backend import db


class SecurityLog(db.Model):
    __tablename__ = 'security_logs'

    log_id = db.Column(db.Integer, primary_key=True)
    event = db.Column(db.String(100), nullable=False)
    severity = db.Column(db.Enum('Info', 'Warning', 'Critical'), default='Info')
    ip_address = db.Column(db.String(45))
    details = db.Column(db.Text)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    def to_dict(self):
        return {
            'log_id': self.log_id,
            'event': self.event,
            'severity': self.severity,
            'ip_address': self.ip_address,
            'details': self.details,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f"<SecurityLog {self.log_id} {self.event}>"

