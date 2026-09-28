/// Models for vote results and verification, mirroring the backend
/// `/report/results/<id>` and `/report/verify` response payloads.
class CandidateResult {
  final int candidateId;
  final String name;
  final String? party;
  final String? symbol;
  final int votes;

  const CandidateResult({
    required this.candidateId,
    required this.name,
    this.party,
    this.symbol,
    this.votes = 0,
  });

  factory CandidateResult.fromJson(Map<String, dynamic> json) {
    return CandidateResult(
      candidateId: json['candidate_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      party: json['party'] as String?,
      symbol: json['symbol'] as String?,
      votes: json['votes'] as int? ?? 0,
    );
  }
}

class ElectionResult {
  final int electionId;
  final String? electionName;
  final int totalVotes;
  final double turnout;
  final List<CandidateResult> results;

  const ElectionResult({
    required this.electionId,
    this.electionName,
    this.totalVotes = 0,
    this.turnout = 0,
    this.results = const [],
  });

  factory ElectionResult.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? const [];
    return ElectionResult(
      electionId: json['election_id'] as int? ?? 0,
      electionName: json['election_name'] as String?,
      totalVotes: json['total_votes'] as int? ?? 0,
      turnout: (json['turnout'] is Map)
          ? ((json['turnout'] as Map)['turnout_percentage'] as num?)?.toDouble() ?? 0
          : (json['turnout'] as num?)?.toDouble() ?? 0,
      results: rawResults
          .map((e) => CandidateResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Largest vote count (for proportional bar rendering).
  int get maxVotes =>
      results.fold(0, (m, r) => r.votes > m ? r.votes : m);
}

class VerifyResult {
  final int totalVotes;
  final int verifiedVotes;
  final int failedVotes;
  final List<Map<String, dynamic>> failedDetails;

  const VerifyResult({
    this.totalVotes = 0,
    this.verifiedVotes = 0,
    this.failedVotes = 0,
    this.failedDetails = const [],
  });

  factory VerifyResult.fromJson(Map<String, dynamic> json) {
    return VerifyResult(
      totalVotes: json['total_votes'] as int? ?? 0,
      verifiedVotes: json['verified_votes'] as int? ?? 0,
      failedVotes: json['failed_votes'] as int? ?? 0,
      failedDetails: (json['failed_details'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
    );
  }
}

class VoteTokenVerificationResult {
  final bool found;
  final bool valid;
  final String token;
  final int? voteId;
  final int? electionId;
  final int? candidateId;
  final int? voterId;
  final String? timestamp;
  final bool isVerified;
  final List<String> reasons;
  final String? message;

  const VoteTokenVerificationResult({
    required this.found,
    required this.valid,
    required this.token,
    this.voteId,
    this.electionId,
    this.candidateId,
    this.voterId,
    this.timestamp,
    this.isVerified = false,
    this.reasons = const [],
    this.message,
  });

  factory VoteTokenVerificationResult.fromJson(Map<String, dynamic> json) {
    return VoteTokenVerificationResult(
      found: json['found'] as bool? ?? false,
      valid: json['valid'] as bool? ?? false,
      token: json['token'] as String? ?? '',
      voteId: json['vote_id'] as int?,
      electionId: json['election_id'] as int?,
      candidateId: json['candidate_id'] as int?,
      voterId: json['voter_id'] as int?,
      timestamp: json['timestamp'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      reasons: (json['reasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      message: json['message'] as String?,
    );
  }
}

