import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/voter.dart';

class VoterProvider extends ChangeNotifier {
  VoterProvider(this._api);

  final ApiClient _api;

  List<Voter> _voters = [];
  Voter? _selectedVoter;
  bool _loading = false;
  String? _error;

  List<Voter> get voters => _voters;
  Voter? get selectedVoter => _selectedVoter;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> fetchVoters({String? query}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.get(
        '/voter/list',
        query: query == null || query.isEmpty ? null : {'q': query},
      ) as Map<String, dynamic>;
      final raw = data['voters'] as List<dynamic>? ?? [];
      _voters = raw.map((v) => Voter.fromJson(v as Map<String, dynamic>)).toList();
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      _voters = [];
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> fetchVoterDetail(int voterId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.get('/voter/detail/$voterId') as Map<String, dynamic>;
      final voterJson = data['voter'] as Map<String, dynamic>?;
      if (voterJson == null) {
        _error = 'Voter data is missing from response.';
        return false;
      }
      _selectedVoter = Voter.fromJson(voterJson);
      return true;
    } catch (e) {
      // Provide more detailed error info for debugging UI issues.
      if (e is ApiException) {
        _error = '${e.message}${e.data != null ? ' - ${e.data}' : ''}';
      } else {
        _error = ApiClient.friendlyMessage(e);
      }
      _selectedVoter = null;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> fetchVotersForElection(int electionId, {String? query}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.get(
        '/election/$electionId/voters',
        query: query == null || query.isEmpty ? null : {'q': query},
      ) as Map<String, dynamic>;
      final raw = data['voters'] as List<dynamic>? ?? [];
      _voters = raw.map((v) => Voter.fromJson(v as Map<String, dynamic>)).toList();
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      _voters = [];
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _voters = [];
    _selectedVoter = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
