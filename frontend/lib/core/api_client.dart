import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Centralized HTTP client for the Secure Electronic Voting System backend.
///
/// - Holds the base URL for the Flask API.
/// - Attaches the JWT Authorization header when a token is present.
/// - Parses JSON responses and raises [ApiException] on non-2xx responses.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = client ?? http.Client();

  static const String _defaultBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5000');

  final String baseUrl;
  final http.Client _client;

  /// The current JWT token, e.g. from [AuthProvider].
  String? authToken;

  String get apiBaseUrl => baseUrl;

  /// Convenience `true` when a token is set.
  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;

  Uri _uri(String path, {Map<String, String>? query}) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(queryParameters: query);
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  // ---- HTTP verbs --------------------------------------------------------

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final resp = await _client.get(_uri(path, query: query), headers: _headers);
    return _decode(resp);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final resp = await _client.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(resp);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final resp = await _client.put(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(resp);
  }

  Future<dynamic> delete(String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) async {
    final resp = await _client.delete(
      _uri(path, query: query),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(resp);
  }

  // ---- Response handling -------------------------------------------------

  dynamic _decode(http.Response resp) {
    final body = resp.body.isEmpty ? <String, dynamic>{} : _tryDecode(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body;
    }
    throw ApiException(
      statusCode: resp.statusCode,
      message: _extractError(body) ?? 'Request failed (${resp.statusCode})',
      data: body,
    );
  }

  dynamic _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  String? _extractError(dynamic body) {
    if (body is Map && body['error'] != null) {
      return body['error'].toString();
    }
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    return null;
  }

  /// Helper to convert an [ApiException] into a user-friendly message.
  static String friendlyMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is SocketException) {
      return 'Cannot reach the server. Make sure the backend is running.';
    }
    if (error is http.ClientException) {
      return 'Network error. Please check your connection.';
    }
    return error.toString();
  }
}

/// Thrown when the backend returns a non-2xx response.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });

  final int statusCode;
  final String message;
  final dynamic data;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

