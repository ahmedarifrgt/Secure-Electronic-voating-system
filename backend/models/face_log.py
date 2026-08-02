from backend import db


class FaceLog(db.Model):
    __tablename__ = 'face_logs'

    log_id = db.Column(db.Integer, primary_key=True)
    voter_id = db.Column(db.Integer, db.ForeignKey('voters.voter_id'), nullable=True)
    nid = db.Column(db.String(20))
    stage = db.Column(db.String(50))
    status = db.Column(db.Enum('Success', 'Failed', 'Skipped'), default='Skipped')
    confidence = db.Column(db.DECIMAL(6, 4))
    details = db.Column(db.Text)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    def to_dict(self):
        return {
            'log_id': self.log_id,
            'voter_id': self.voter_id,
            'nid': self.nid,
            'stage': self.stage,
            'status': self.status,
            'confidence': float(self.confidence) if self.confidence is not None else None,
            'details': self.details,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }

    def __repr__(self):
        return f"<FaceLog {self.log_id} {self.stage} {self.status}>"

