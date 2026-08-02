import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/dashboard_stats.dart';
import '../models/election.dart';
import '../models/vote_result.dart';

/// Admin dashboard data + actions:
/// - stats, election list
/// - integrity verification (`/report/verify`)
/// - publish results (`/report/publish/<id>`)
/// - public results (`/report/results/<id>`)
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._api);

  final ApiClient _api;

  DashboardStats? _stats;
  List<Election> _elections = const [];
  bool _loading = false;
  String? _error;

  // Integrity / results state
  VerifyResult? _verifyResult;
  ElectionResult? _publishedResult;
  bool _verifying = false;

  DashboardStats? get stats => _stats;
  List<Election> get elections => _elections;
  bool get loading => _loading;
  String? get error => _error;
  VerifyResult? get verifyResult => _verifyResult;
  ElectionResult? get publishedResult => _publishedResult;
  bool get verifying => _verifying;

  /// Load dashboard stats for the admin home screen.
  Future<bool> fetchStats() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get('/dashboard/stats') as Map<String, dynamic>;
      _stats = DashboardStats.fromJson(data);
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Load all elections (optionally filtered by status).
  Future<bool> fetchElections({String? status}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get(
        '/election/list',
        query: status == null ? null : {'status': status},
      ) as Map<String, dynamic>;
      final raw = data['elections'] as List<dynamic>? ?? const [];
      _elections = raw
          .map((e) => Election.fromJson(e as Map<String, dynamic>))
          .toList();
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Run integrity verification across all stored votes.
  Future<bool> verifyIntegrity() async {
    _verifying = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get('/report/verify') as Map<String, dynamic>;
      _verifyResult = VerifyResult.fromJson(data);
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _verifying = false;
      notifyListeners();
    }
  }

  /// Publish results for an election.
  Future<bool> publishResults(int electionId) async {
    _verifying = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.post('/report/publish/$electionId') as Map<String, dynamic>;
      _publishedResult = _readPublished(data);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _verifying = false;
      notifyListeners();
    }
  }

  /// Fetch public results for an election.
  Future<bool> fetchResults(int electionId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.get('/report/results/$electionId') as Map<String, dynamic>;
      _publishedResult = ElectionResult.fromJson(data);
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  ElectionResult _readPublished(Map<String, dynamic> data) {
    // The publish endpoint returns `{election_id, election_name, total_votes,
    // turnout: {...}, results: [...]}` — ElectionResult.fromJson handles it.
    return ElectionResult.fromJson(data);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _stats = null;
    _elections = const [];
    _verifyResult = null;
    _publishedResult = null;
    _error = null;
    notifyListeners();
  }
}

