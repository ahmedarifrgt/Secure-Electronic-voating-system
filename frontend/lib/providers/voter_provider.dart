import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/voter.dart';

/// Result of an admin voter registration request.
class VoterRegistrationResult {
  const VoterRegistrationResult({
    required this.voterId,
    required this.nid,
    required this.fullName,
    required this.savedImagePath,
    required this.registrationTime,
  });

  final int? voterId;
  final String? nid;
  final String? fullName;
  final String? savedImagePath;
  final String? registrationTime;

  factory VoterRegistrationResult.fromJson(Map<String, dynamic> json) {
    return VoterRegistrationResult(
      voterId: json['voter_id'] as int?,
      nid: json['nid'] as String?,
      fullName: json['full_name'] as String?,
      savedImagePath: json['saved_image_path'] as String?,
      registrationTime: json['registration_time'] as String?,
    );
  }
}

class VoterProvider extends ChangeNotifier {
  VoterProvider(this._api);

  final ApiClient _api;

  String get apiBaseUrl => _api.apiBaseUrl;

  List<Voter> _voters = [];
  Voter? _selectedVoter;
  bool _loading = false;
  String? _error;

  List<Voter> get voters => _voters;
  Voter? get selectedVoter => _selectedVoter;
  bool get loading => _loading;
  String? get error => _error;

  /// Registers a new voter through the admin-only `/voter/create` endpoint.
  ///
/// The backend validates the payload, captures the face via the server camera,
  /// saves the face image, generates the embedding, and inserts the record.
  ///
  /// Throws [ApiException] on failure (e.g. 400 validation, 409 duplicate NID or
  /// duplicate face image, 422 camera error). The caller can inspect
  /// `e.data['duplicate_image']` to prompt the admin to replace an existing image.
  Future<VoterRegistrationResult> createVoter({
    required String nid,
    required String fullName,
    String? fatherName,
    String? motherName,
    required String dob,
    required String gender,
    String? mobile,
    String? email,
    String? permanentAddress,
    String? presentAddress,
    String? areaCode,
    String? constituency,
    bool registrationStatus = false,
    bool eligibilityStatus = false,
    String? accountStatus,
    bool replaceExistingImage = false,
    int? cameraIndex,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'nid': nid,
        'full_name': fullName,
        'father_name': fatherName,
        'mother_name': motherName,
        'dob': dob,
        'gender': gender,
        'mobile': mobile,
        'email': email,
        'permanent_address': permanentAddress,
        'present_address': presentAddress,
        'area_code': areaCode,
        'constituency': constituency,
        'registration_status': registrationStatus,
        'eligibility_status': eligibilityStatus,
        'account_status': accountStatus ?? 'Active',
        'replace_existing_image': replaceExistingImage,
      };
      if (cameraIndex != null) {
        body['camera_index'] = cameraIndex;
      }

      final data = await _api.post('/voter/create', body: body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>? ?? {};
      return VoterRegistrationResult.fromJson(result);
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Voter> updateVoter({
    required int voterId,
    required String nid,
    required String fullName,
    String? fatherName,
    String? motherName,
    required String dob,
    required String gender,
    String? mobile,
    String? email,
    String? permanentAddress,
    String? presentAddress,
    String? areaCode,
    String? constituency,
    bool registrationStatus = false,
    bool eligibilityStatus = false,
    String? accountStatus,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'nid': nid,
        'full_name': fullName,
        'father_name': fatherName,
        'mother_name': motherName,
        'dob': dob,
        'gender': gender,
        'mobile': mobile,
        'email': email,
        'permanent_address': permanentAddress,
        'present_address': presentAddress,
        'area_code': areaCode,
        'constituency': constituency,
        'registration_status': registrationStatus,
        'eligibility_status': eligibilityStatus,
        'account_status': accountStatus ?? 'Active',
      };

      final data = await _api.put('/voter/update/$voterId', body: body) as Map<String, dynamic>;
      final voterJson = data['voter'] as Map<String, dynamic>?;
      if (voterJson == null) {
        throw StateError('Voter data is missing from the update response.');
      }

      final updated = Voter.fromJson(voterJson);
      _selectedVoter = updated;
      _voters = _voters
          .map((v) => v.voterId == updated.voterId ? updated : v)
          .toList();
      return updated;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

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
