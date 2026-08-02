from backend import db


class Voter(db.Model):
    __tablename__ = 'voters'

    voter_id = db.Column(db.Integer, primary_key=True)
    nid = db.Column(db.String(20), unique=True, nullable=False)
    full_name = db.Column(db.String(100), nullable=False)
    father_name = db.Column(db.String(100))
    mother_name = db.Column(db.String(100))
    dob = db.Column(db.Date, nullable=False)
    gender = db.Column(db.Enum('Male', 'Female', 'Other'))
    mobile = db.Column(db.String(15))
    email = db.Column(db.String(100))
    permanent_address = db.Column(db.Text)
    present_address = db.Column(db.Text)
    area_code = db.Column(db.String(10))
    constituency = db.Column(db.String(50))
    face_image_path = db.Column(db.String(255))
    face_embedding = db.Column(db.LargeBinary(512))
    registration_status = db.Column(db.Boolean, default=False)
    eligibility_status = db.Column(db.Boolean, default=False)
    has_voted = db.Column(db.Boolean, default=False)
    last_login = db.Column(db.DateTime)
    account_status = db.Column(db.Enum('Active', 'Inactive'), default='Active')
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now())

    def to_public_dict(self):
        """Return a safe representation without sensitive fields."""
        return {
            'voter_id': self.voter_id,
            'nid': self.nid,
            'full_name': self.full_name,
            'face_image_path': self.face_image_path,
            'father_name': self.father_name,
            'mother_name': self.mother_name,
            'dob': self.dob.isoformat() if self.dob else None,
            'gender': self.gender,
            'mobile': self.mobile,
            'email': self.email,
            'permanent_address': self.permanent_address,
            'present_address': self.present_address,
            'area_code': self.area_code,
            'constituency': self.constituency,
            'registration_status': self.registration_status,
            'eligibility_status': self.eligibility_status,
            'has_voted': self.has_voted,
            'account_status': self.account_status,
            'last_login': self.last_login.isoformat() if self.last_login else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }

    def __repr__(self):
        return f"<Voter {self.voter_id} {self.nid} {self.full_name}>"

