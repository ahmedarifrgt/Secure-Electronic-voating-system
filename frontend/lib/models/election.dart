/// Election model mirroring `backend/models/election.py to_dict()`.
class Election {
  final int electionId;
  final String name;
  final String? description;
  final String? areaCode;
  final String? constituency;
  final String? startDate;
  final String? endDate;
  final String status;

  const Election({
    required this.electionId,
    required this.name,
    this.description,
    this.areaCode,
    this.constituency,
    this.startDate,
    this.endDate,
    this.status = 'Upcoming',
  });

  factory Election.fromJson(Map<String, dynamic> json) {
    return Election(
      electionId: json['election_id'] as int,
      name: json['name'] as String? ?? 'Untitled Election',
      description: json['description'] as String?,
      areaCode: json['area_code'] as String?,
      constituency: json['constituency'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      status: json['status'] as String? ?? 'Upcoming',
    );
  }

  bool get isActive => status == 'Active';

  /// Formatted date range e.g. "Jan 10 – Feb 02 2025".
  String get dateRangeLabel {
    final s = _formatDate(startDate);
    final e = _formatDate(endDate);
    if (s == null && e == null) return 'Dates not set';
    if (s == null) return 'Ends $e';
    if (e == null) return 'Starts $s';
    return '$s – $e';
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final y = dt.year;
    final m = months[dt.month - 1];
    final d = dt.day.toString().padLeft(2, '0');
    final today = DateTime.now();
    return (y == today.year) ? '$m $d' : '$m $d $y';
  }
}

