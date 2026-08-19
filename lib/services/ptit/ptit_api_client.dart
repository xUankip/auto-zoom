import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ptit_models.dart';

/// HTTP client for the PTIT student portal (qldttx.pttc1.edu.vn).
///
/// Auth flow:
///   POST /api/auth/login  (form-encoded, grant_type=password)
///         → JWT access_token
///   POST /api/sch/w-locdshockytkbuser
///         → current semester code (hoc_ky e.g. 20261)
///   POST /api/sch/w-locdstkbtuanusertheohocky
///         → all weeks of semester in one call
class PtitApiClient {
  static const _baseUrl = 'https://qldttx.pttc1.edu.vn';
  static const _loginPath = '/api/auth/login';
  static const _semesterPath = '/api/sch/w-locdshockytkbuser';
  static const _tkbPath = '/api/sch/w-locdstkbtuanusertheohocky';

  final http.Client _http;

  PtitApiClient({http.Client? client}) : _http = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// OAuth2 Password Flow – must be form-encoded, NOT JSON.
  Future<PtitSession> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl$_loginPath');

    final headers = {
      HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
      HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
      'Origin': _baseUrl,
      'Referer': '$_baseUrl/',
    };

    final body = {
      'grant_type': 'password',
      'username': username,
      'password': password,
    };

    debugPrint('[PtitApiClient] POST $uri (OAuth2 form-encoded)');
    final response = await _http.post(uri, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw PtitAuthException(
        'Đăng nhập thất bại (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const PtitAuthException('Không tìm thấy access_token trong phản hồi.');
    }

    // Response uses "userName" (capital N) and "name"
    final studentCode =
        data['userName'] as String? ?? data['username'] as String? ?? username;
    final studentName = data['name'] as String? ?? '';

    return PtitSession(
      accessToken: token,
      studentCode: studentCode,
      studentName: studentName,
    );
  }

  // ---------------------------------------------------------------------------
  // Semester
  // ---------------------------------------------------------------------------

  /// Returns the current semester code (e.g. 20261 = Year 2026, Semester 1).
  Future<int> fetchCurrentSemester(PtitSession session) async {
    final uri = Uri.parse('$_baseUrl$_semesterPath');
    final headers = _authHeaders(session);

    debugPrint('[PtitApiClient] POST $uri (semester list)');
    final response = await _http.post(uri, headers: headers, body: '{}');

    if (response.statusCode != 200) {
      throw PtitApiException('Lỗi lấy học kỳ: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;

    // hoc_ky_theo_ngay_hien_tai is the currently active semester
    final current = data?['hoc_ky_theo_ngay_hien_tai'] as int?;
    if (current != null && current > 0) return current;

    // Fall back to the first ds_hoc_ky entry
    final list = data?['ds_hoc_ky'] as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      final first = list.first as Map<String, dynamic>;
      return (first['hoc_ky'] as int?) ?? 0;
    }

    throw const PtitApiException('Không xác định được học kỳ hiện tại.');
  }

  // ---------------------------------------------------------------------------
  // Timetable
  // ---------------------------------------------------------------------------

  /// Fetch the ENTIRE semester timetable in a single call.
  ///
  /// Returns flat list of [PtitClass] across all weeks.
  Future<List<PtitClass>> fetchSemesterTkb({
    required PtitSession session,
    required int hocKy,
  }) async {
    final uri = Uri.parse('$_baseUrl$_tkbPath');
    final headers = _authHeaders(session);

    // Fetch all weeks (1-30) in one call – API returns only present weeks
    final payload = jsonEncode({
      'filter': {
        'hoc_ky': hocKy,
        'tu_tuan': 1,
        'den_tuan': 30,
      },
      'paginator': {'page': 1, 'limit': 200},
    });

    debugPrint('[PtitApiClient] POST $uri (full semester hoc_ky=$hocKy)');
    final response = await _http.post(uri, headers: headers, body: payload);

    if (response.statusCode == 401) {
      throw const PtitAuthException('Token hết hạn (401).');
    }
    if (response.statusCode != 200) {
      throw PtitApiException('Lỗi lấy TKB: HTTP ${response.statusCode}');
    }

    return _parseResponse(response.body);
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Map<String, String> _authHeaders(PtitSession session) => {
        HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
        'Origin': _baseUrl,
        'Referer': '$_baseUrl/',
      };

  List<PtitClass> _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final dsTuan = data?['ds_tuan_tkb'] as List<dynamic>?;
      if (dsTuan == null) return [];

      final result = <PtitClass>[];
      for (final tuanRaw in dsTuan) {
        final tuan = tuanRaw as Map<String, dynamic>;
        final weekIndex = tuan['tuan_hoc_ky'] as int? ?? 0;
        final ngayBatDau = tuan['ngay_bat_dau'] as String? ?? '';
        final dsTkb = tuan['ds_thoi_khoa_bieu'] as List<dynamic>? ?? [];

        for (final tkbRaw in dsTkb) {
          final tkb = tkbRaw as Map<String, dynamic>;
          // Skip cancelled lessons
          if (tkb['is_nghi_day'] == true) continue;

          result.add(PtitClass.fromJson(tkb, weekIndex: weekIndex, weekStartDate: ngayBatDau));
        }
      }
      return result;
    } catch (e) {
      debugPrint('[PtitApiClient] Parse error: $e');
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
