import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ptit_models.dart';

/// HTTP client for the PTIT student portal (qldttx.pttc1.edu.vn).
///
/// Auth flow mirrors the Angular SPA:
///   POST /api/auth/login → receives JWT access_token
///   GET  sch/w-locdstkbtuanusertheohocky?... → returns weekly timetable JSON
class PtitApiClient {
  static const _baseUrl = 'https://qldttx.pttc1.edu.vn';
  static const _loginPath = '/api/auth/login';
  static const _tkbPath = '/sch/w-locdstkbtuanusertheohocky';

  final http.Client _http;

  PtitApiClient({http.Client? client}) : _http = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Login with username & password. Returns a [PtitSession] with JWT token.
  Future<PtitSession> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl$_loginPath');

    final headers = {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
      'Origin': _baseUrl,
      'Referer': '$_baseUrl/',
    };

    final body = jsonEncode({'username': username, 'password': password});

    debugPrint('[PtitApiClient] POST $uri');
    final response = await _http.post(uri, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw PtitAuthException(
        'Login failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final token = data['access_token'] as String? ?? data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw PtitAuthException('No access_token in login response.');
    }

    final user = data['data'] as Map<String, dynamic>? ?? data;
    final studentCode =
        user['username'] as String? ?? user['mssv'] as String? ?? username;
    final studentName =
        user['name'] as String? ?? user['ho_ten'] as String? ?? '';

    return PtitSession(
      accessToken: token,
      studentCode: studentCode,
      studentName: studentName,
    );
  }

  // ---------------------------------------------------------------------------
  // Timetable
  // ---------------------------------------------------------------------------

  /// Fetch [PtitClass] list for a specific [weekIndex] (1-based).
  Future<List<PtitClass>> fetchWeek({
    required PtitSession session,
    required int weekIndex,
  }) async {
    final uri = Uri.parse('$_baseUrl$_tkbPath').replace(queryParameters: {
      'filter[hoc_ky]': '',
      'filter[ten_hoc_ky]': '',
      'filter[tu_tuan]': weekIndex.toString(),
      'filter[den_tuan]': weekIndex.toString(),
      'page': '1',
      'rpp': '100',
    });

    final headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
      HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
      'Origin': _baseUrl,
      'Referer': '$_baseUrl/',
    };

    debugPrint('[PtitApiClient] GET $uri');
    final response = await _http.get(uri, headers: headers);

    if (response.statusCode == 401) {
      throw PtitAuthException('Token expired or invalid (401).');
    }
    if (response.statusCode != 200) {
      throw PtitApiException(
        'TKB fetch failed (week $weekIndex): HTTP ${response.statusCode}',
      );
    }

    return _parseClasses(response.body, weekIndex);
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  List<PtitClass> _parseClasses(String body, int weekIndex) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final rawList = data?['ds_tiet_trong_tuan'] as List<dynamic>?;
      if (rawList == null || rawList.isEmpty) return [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((e) => PtitClass.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('[PtitApiClient] Parse error on week $weekIndex: $e');
      return [];
    }
  }
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class PtitAuthException implements Exception {
  final String message;
  const PtitAuthException(this.message);
  @override
  String toString() => 'PtitAuthException: $message';
}

class PtitApiException implements Exception {
  final String message;
  const PtitApiException(this.message);
  @override
  String toString() => 'PtitApiException: $message';
}
