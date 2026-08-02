from backend import db


class Vote(db.Model):
    __tablename__ = "votes"
    vote_id = db.Column(db.Integer, primary_key=True)
    election_id = db.Column(db.Integer, nullable=False)
    voter_id = db.Column(db.Integer, nullable=False)
    candidate_id = db.Column(db.Integer, nullable=False)
    encrypted_vote = db.Column(db.LargeBinary, nullable=False)
    hash = db.Column(db.String(64), nullable=False)
    signature = db.Column(db.Text, nullable=False)
    iv = db.Column(db.String(64), nullable=False)
    token = db.Column(db.String(128), unique=True, nullable=False)
    is_verified = db.Column(db.Boolean, default=False)
    timestamp = db.Column(db.DateTime, server_default=db.func.now())

    def to_dict(self):
        return {
            'vote_id': self.vote_id,
            'election_id': self.election_id,
            'voter_id': self.voter_id,
            'candidate_id': self.candidate_id,
            'hash': self.hash,
            'signature': self.signature,
            'iv': self.iv,
            'token': self.token,
            'is_verified': self.is_verified,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
        }

    def __repr__(self):
        return f"<Vote {self.vote_id} election={self.election_id} voter={self.voter_id}>"

