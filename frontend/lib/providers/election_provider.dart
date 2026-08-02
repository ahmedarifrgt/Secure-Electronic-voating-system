import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/candidate.dart';
import '../models/election.dart';

/// Manages the voter election flow:
/// - eligible elections for the authenticated voter
/// - candidates for a selected election
/// - casting a vote via `/vote/cast`
class ElectionProvider extends ChangeNotifier {
  ElectionProvider(this._api);

  final ApiClient _api;

  List<Election> _elections = const [];
  List<Candidate> _candidates = const [];
  bool _loading = false;
  String? _error;

  // Vote casting state
  bool _submitting = false;
  String? _voteToken;
  int? _voteId;

  List<Election> get elections => _elections;
  List<Candidate> get candidates => _candidates;
  bool get loading => _loading;
  String? get error => _error;
  bool get submitting => _submitting;
  String? get voteToken => _voteToken;
  int? get voteId => _voteId;

  /// Fetch elections the authenticated voter is eligible for.
  Future<bool> fetchEligibleElections(int voterId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get('/election/eligible/$voterId') as Map<String, dynamic>;
      final raw = data['elections'] as List<dynamic>? ?? const [];
      _elections = raw
          .map((e) => Election.fromJson(e as Map<String, dynamic>))
          .where((e) => e.isActive)
          .toList();
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      _elections = const [];
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch active candidates for a specific election.
  Future<bool> fetchCandidates(int electionId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get('/candidate/list/$electionId') as Map<String, dynamic>;
      final raw = data['candidates'] as List<dynamic>? ?? const [];
      _candidates = raw
          .map((c) => Candidate.fromJson(c as Map<String, dynamic>))
          .toList();
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      _candidates = const [];
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Create a new election from the admin dashboard.
  /// Returns the created election map on success, or `null` on failure.
  Future<Map<String, dynamic>?> createElection({
    required String name,
    String? description,
    String? areaCode,
    String? constituency,
    required String startDate,
    required String endDate,
    required String status,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.post('/election/create', body: {
        'name': name,
        'description': description,
        'area_code': areaCode,
        'constituency': constituency,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
      }) as Map<String, dynamic>;
      return data['election'] as Map<String, dynamic>?;
    } catch (e) {
      // Surface more detailed error information for debugging (network/CORS/403/etc.)
      // Also print to console so it appears in browser/IDE logs.
      // Keep the friendly message as well but include raw exception text.
      try {
        // ignore: avoid_print
        print('createElection error: $e');
      } catch (_) {}
      final friendly = ApiClient.friendlyMessage(e);
      _error = '$friendly (${e.toString()})';
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Publish an election (set status=Active).
  Future<bool> publishElection(int electionId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.post('/election/publish/$electionId');
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Add a new candidate to an election (admin).
  Future<bool> addCandidate({
    required int electionId,
    required String name,
    String? party,
    String? symbol,
    String? areaCode,
    String? constituency,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.post('/candidate/add', body: {
        'election_id': electionId,
        'name': name,
        'party': party,
        'symbol': symbol,
        'area_code': areaCode,
        'constituency': constituency,
      }) as Map<String, dynamic>;
      final raw = data['candidate'] as Map<String, dynamic>?;
      if (raw != null) {
        final created = Candidate.fromJson(raw);
        _candidates = [..._candidates, created];
      }
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Send a notify request for voters of an election. Returns true on success.
  Future<bool> notifyVoters(int electionId, {String? message}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.post('/election/$electionId/notify', body: message == null ? null : {'message': message});
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Cast a vote for [candidateId] in [electionId].
  Future<bool> castVote({
    required int electionId,
    required int candidateId,
  }) async {
    _submitting = true;
    _error = null;
    _voteToken = null;
    _voteId = null;
    notifyListeners();
    try {
      final data = await _api.post('/vote/cast', body: {
        'election_id': electionId,
        'candidate_id': candidateId,
      }) as Map<String, dynamic>;

      _voteToken = data['token'] as String?;
      _voteId = data['vote_id'] as int?;
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void reset() {
    _elections = const [];
    _candidates = const [];
    _voteToken = null;
    _voteId = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

