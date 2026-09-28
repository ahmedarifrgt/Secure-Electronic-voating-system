/// Voter model mirroring `backend/models/voter.py to_public_dict()`.
class Voter {
  final int? voterId;
  final String? nid;
  final String? fullName;
  final String? gender;
  final String? areaCode;
  final String? constituency;
  final String? fatherName;
  final String? motherName;
  final String? dob;
  final String? mobile;
  final String? email;
  final String? permanentAddress;
  final String? presentAddress;
  final String? faceImagePath;
  final String? faceImageUrl;
  final bool registrationStatus;
  final bool eligibilityStatus;
  final bool hasVoted;
  final String? accountStatus;
  final String? createdAt;
  final String? lastLogin;
  final String? updatedAt;

  const Voter({
    this.voterId,
    this.nid,
    this.fullName,
    this.fatherName,
    this.motherName,
    this.dob,
    this.gender,
    this.mobile,
    this.email,
    this.permanentAddress,
    this.presentAddress,
    this.areaCode,
    this.constituency,
    this.registrationStatus = false,
    this.eligibilityStatus = false,
    this.hasVoted = false,
    this.accountStatus,
    this.createdAt,
    this.lastLogin,
    this.updatedAt,
    this.faceImagePath,
    this.faceImageUrl,
  });

  factory Voter.fromJson(Map<String, dynamic> json) {
    return Voter(
      voterId: json['voter_id'] as int?,
      nid: json['nid'] as String?,
      fullName: json['full_name'] as String?,
      fatherName: json['father_name'] as String?,
      motherName: json['mother_name'] as String?,
      dob: json['dob'] as String?,
      gender: json['gender'] as String?,
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      permanentAddress: json['permanent_address'] as String?,
      presentAddress: json['present_address'] as String?,
      areaCode: json['area_code'] as String?,
      constituency: json['constituency'] as String?,
      faceImagePath: json['face_image_path'] as String?,
      faceImageUrl: json['face_image_url'] as String?,
      registrationStatus: json['registration_status'] == true,
      eligibilityStatus: json['eligibility_status'] == true,
      hasVoted: json['has_voted'] == true,
      accountStatus: json['account_status'] as String?,
      createdAt: json['created_at'] as String?,
      lastLogin: json['last_login'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  bool get isEligible => eligibilityStatus;

  String get initials {
    if (fullName == null || fullName!.isEmpty) return '?';
    final parts = fullName!.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

