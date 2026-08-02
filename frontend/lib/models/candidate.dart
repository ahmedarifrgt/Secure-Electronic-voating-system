/// Candidate model mirroring `backend/models/candidate.py to_dict()`.
class Candidate {
  final int candidateId;
  final int electionId;
  final String name;
  final String? party;
  final String? symbol;
  final String? areaCode;
  final String? constituency;
  final String status;

  const Candidate({
    required this.candidateId,
    required this.electionId,
    required this.name,
    this.party,
    this.symbol,
    this.areaCode,
    this.constituency,
    this.status = 'Active',
  });

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      candidateId: json['candidate_id'] as int,
      electionId: json['election_id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      party: json['party'] as String?,
      symbol: json['symbol'] as String?,
      areaCode: json['area_code'] as String?,
      constituency: json['constituency'] as String?,
      status: json['status'] as String? ?? 'Active',
    );
  }

  bool get isActive => status == 'Active';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

