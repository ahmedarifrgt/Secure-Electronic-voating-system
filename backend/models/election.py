from backend import db


class Election(db.Model):
    __tablename__ = 'elections'

    election_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    description = db.Column(db.Text)
    area_code = db.Column(db.String(10))
    constituency = db.Column(db.String(50))
    start_date = db.Column(db.DateTime, nullable=False)
    end_date = db.Column(db.DateTime, nullable=False)
    status = db.Column(db.Enum('Upcoming', 'Active', 'Completed'), default='Upcoming')
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now())

    candidates = db.relationship('Candidate', backref='election', lazy='dynamic')

    def to_dict(self):
        return {
            'election_id': self.election_id,
            'name': self.name,
            'description': self.description,
            'area_code': self.area_code,
            'constituency': self.constituency,
            'start_date': self.start_date.isoformat() if self.start_date else None,
            'end_date': self.end_date.isoformat() if self.end_date else None,
            'status': self.status,
        }

    def __repr__(self):
        return f"<Election {self.election_id} {self.name}>"

