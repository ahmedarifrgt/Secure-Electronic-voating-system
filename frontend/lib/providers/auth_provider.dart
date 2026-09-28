import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/face_verification_result.dart';
import '../models/voter.dart';

/// Holds authentication state for both voters and admins.
///
/// - Persists the JWT in `shared_preferences` so the user stays logged in.
/// - Exposes `loginVoter` (NID + live selfie) and `loginAdmin`.
/// - Carries the authenticated [Voter] details after voter login.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api);

  final ApiClient _api;

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _voterKey = 'auth_voter';

  String? _token;
  String? _role;
  Voter? _voter;
  FaceVerificationResult? _lastVerification;
  bool _loading = false;
  String? _error;

  String? get token => _token;
  String? get role => _role;
  Voter? get voter => _voter;
  FaceVerificationResult? get lastVerification => _lastVerification;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  bool get isAdmin => _role == 'admin';
  bool get isVoter => _role == 'voter';

  /// Load a persisted session (called once at app startup).
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _role = prefs.getString(_roleKey);
    final voterJson = prefs.getString(_voterKey);
    if (voterJson != null) {
      try {
        _voter = Voter.fromJson(jsonDecode(voterJson) as Map<String, dynamic>);
      } catch (_) {
        _voter = null;
      }
    }
    if (_token != null) {
      _api.authToken = _token;
    }
    notifyListeners();
  }

  /// Voter login: NID + live webcam frame captured for face verification.
  ///
  /// Returns `true` when the face matched and a JWT was issued. On failure,
  /// [lastVerification] holds the detailed pipeline result (score, distance,
  /// per-stage breakdown) returned by the backend.
  Future<bool> loginVoter({
    required String nid,
    XFile? liveImage,
    List<XFile> extraImages = const [],
  }) async {
    _loading = true;
    _error = null;
    _lastVerification = null;
    notifyListeners();

    try {
      String? liveImageB64;
      if (liveImage != null) {
        final bytes = await liveImage.readAsBytes();
        liveImageB64 = base64Encode(bytes);
      }

      final body = <String, dynamic>{
        'nid': nid,
        'live_capture': true,
      };
      if (liveImageB64 != null) {
        body['live_image_b64'] = liveImageB64;
      }

      if (extraImages.isNotEmpty) {
        final extraFrames = <String>[];
        for (final frame in extraImages) {
          final bytes = await frame.readAsBytes();
          extraFrames.add(base64Encode(bytes));
        }
        body['extra_frames'] = extraFrames;
      }

      final data = await _api.post('/auth/login', body: body) as Map<String, dynamic>;

      // Capture verification details (present on both success and 403)
      final verificationJson = data['verification'];
      if (verificationJson is Map<String, dynamic>) {
        _lastVerification = FaceVerificationResult.fromJson(verificationJson);
      }

      final token = data['token'] as String?;
      if (token == null) {
        _error = data['error'] as String? ?? 'Login failed: no token returned';
        return false;
      }

      _token = token;
      _role = data['role'] as String? ?? 'voter';
      _api.authToken = token;

      final voterJson = data['voter'];
      if (voterJson is Map<String, dynamic>) {
        _voter = Voter.fromJson(voterJson);
      }

      await _persist();
      return true;
    } on ApiException catch (e) {
      // A 403 face-verification failure carries a `verification` payload.
      final data = e.data;
      if (data is Map<String, dynamic> && data['verification'] is Map<String, dynamic>) {
        _lastVerification =
            FaceVerificationResult.fromJson(data['verification'] as Map<String, dynamic>);
      }
      _error = e.message;
      return false;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Admin login with username + password.
  Future<bool> loginAdmin({
    required String username,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.post('/auth/login', body: {
        'username': username,
        'password': password,
      }) as Map<String, dynamic>;

      final token = data['token'] as String?;
      if (token == null) {
        _error = 'Login failed: no token returned';
        return false;
      }

      _token = token;
      _role = data['role'] as String? ?? 'admin';
      _voter = null;
      _api.authToken = token;

      await _persist();
      return true;
    } catch (e) {
      _error = ApiClient.friendlyMessage(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _voter = null;
    _api.authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_voterKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_tokenKey, _token!);
    if (_role != null) await prefs.setString(_roleKey, _role!);
    if (_voter != null) {
      await prefs.setString(
        _voterKey,
        jsonEncode({
          'voter_id': _voter!.voterId,
          'nid': _voter!.nid,
          'full_name': _voter!.fullName,
          'gender': _voter!.gender,
          'area_code': _voter!.areaCode,
          'constituency': _voter!.constituency,
          'registration_status': _voter!.registrationStatus,
          'eligibility_status': _voter!.eligibilityStatus,
          'has_voted': _voter!.hasVoted,
          'account_status': _voter!.accountStatus,
          'created_at': _voter!.createdAt,
        }),
      );
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

