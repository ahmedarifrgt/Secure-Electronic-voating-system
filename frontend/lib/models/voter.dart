/// Voter model mirroring `backend/models/voter.py to_public_dict()`.
class Voter {
  final int? voterId;
  final String? nid;
  final String? fullName;
  final String? gender;
  final String? areaCode;
  final String? constituency;
  final bool registrationStatus;
  final bool eligibilityStatus;
  final bool hasVoted;
  final String? accountStatus;
  final String? createdAt;

  const Voter({
    this.voterId,
    this.nid,
    this.fullName,
    this.gender,
    this.areaCode,
    this.constituency,
    this.registrationStatus = false,
    this.eligibilityStatus = false,
    this.hasVoted = false,
    this.accountStatus,
    this.createdAt,
  });

  factory Voter.fromJson(Map<String, dynamic> json) {
    return Voter(
      voterId: json['voter_id'] as int?,
      nid: json['nid'] as String?,
      fullName: json['full_name'] as String?,
      gender: json['gender'] as String?,
      areaCode: json['area_code'] as String?,
      constituency: json['constituency'] as String?,
      registrationStatus: json['registration_status'] == true,
      eligibilityStatus: json['eligibility_status'] == true,
      hasVoted: json['has_voted'] == true,
      accountStatus: json['account_status'] as String?,
      createdAt: json['created_at'] as String?,
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

