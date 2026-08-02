/// Dashboard statistics model mirroring
/// `backend/services/reports/analytics.py dashboard_stats()`.
class DashboardStats {
  final int totalVoters;
  final int activeVoters;
  final int ongoingElections;
  final int votesCast;
  final double turnoutPercentage;
  final int failedVerifications;
  final int spoofAttempts;

  const DashboardStats({
    this.totalVoters = 0,
    this.activeVoters = 0,
    this.ongoingElections = 0,
    this.votesCast = 0,
    this.turnoutPercentage = 0,
    this.failedVerifications = 0,
    this.spoofAttempts = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalVoters: json['total_voters'] as int? ?? 0,
      activeVoters: json['active_voters'] as int? ?? 0,
      ongoingElections: json['ongoing_elections'] as int? ?? 0,
      votesCast: json['votes_cast'] as int? ?? 0,
      turnoutPercentage: (json['turnout_percentage'] as num?)?.toDouble() ?? 0,
      failedVerifications: json['failed_verifications'] as int? ?? 0,
      spoofAttempts: json['spoof_attempts'] as int? ?? 0,
    );
  }
}

