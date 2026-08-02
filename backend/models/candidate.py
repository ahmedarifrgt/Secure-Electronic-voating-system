from backend import db


class Candidate(db.Model):
    __tablename__ = 'candidates'

    candidate_id = db.Column(db.Integer, primary_key=True)
    election_id = db.Column(db.Integer, db.ForeignKey('elections.election_id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    party = db.Column(db.String(100))
    symbol = db.Column(db.String(100))
    area_code = db.Column(db.String(10))
    constituency = db.Column(db.String(50))
    status = db.Column(db.Enum('Active', 'Withdrawn'), default='Active')
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    def to_dict(self):
        return {
            'candidate_id': self.candidate_id,
            'election_id': self.election_id,
            'name': self.name,
            'party': self.party,
            'symbol': self.symbol,
            'area_code': self.area_code,
            'constituency': self.constituency,
            'status': self.status,
        }

    def __repr__(self):
        return f"<Candidate {self.candidate_id} {self.name}>"

