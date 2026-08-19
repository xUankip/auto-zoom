import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';

import '../calendar/calendar_service.dart';
import 'ptit_api_client.dart';
import 'ptit_calendar_writer.dart';
import 'ptit_credential_store.dart';

/// Orchestrates the full PTIT → Device Calendar sync.
///
/// Flow:
///   1. Load or accept credentials
///   2. OAuth2 login → JWT session
///   3. Fetch current semester code
///   4. Fetch full semester TKB in one API call
///   5. Write all classes to device calendar
class PtitSyncService {
  final PtitApiClient _apiClient;
  final PtitCalendarWriter _calendarWriter;
  final PtitCredentialStore _credentialStore;
  final DeviceCalendarPlugin _calendarPlugin;

  PtitSyncService({
    PtitApiClient? apiClient,
    PtitCalendarWriter? calendarWriter,
    PtitCredentialStore? credentialStore,
    DeviceCalendarPlugin? calendarPlugin,
  })  : _apiClient = apiClient ?? PtitApiClient(),
        _calendarWriter = calendarWriter ?? PtitCalendarWriter(),
        _credentialStore = credentialStore ?? const PtitCredentialStore(),
        _calendarPlugin = calendarPlugin ?? DeviceCalendarPlugin();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Run a full sync. [onProgress] receives human-readable status + 0..1 value.
  ///
  /// Returns count of events written. Throws [PtitAuthException] on login failure.
  Future<int> sync({
    required String targetCalendarId,
    required void Function(String message, double progress) onProgress,
    String? username,
    String? password,
  }) async {
    onProgress('Đang tải thông tin đăng nhập…', 0.0);

    String? user = username;
    String? pass = password;

    if (user == null || pass == null) {
      final saved = await _credentialStore.load();
      if (saved == null) {
        throw const PtitAuthException('Chưa có thông tin đăng nhập PTIT.');
      }
      user = saved.username;
      pass = saved.password;
    }

    // Step 1: Login
    onProgress('Đang đăng nhập vào hệ thống PTIT…', 0.05);
    final session = await _apiClient.login(username: user, password: pass);

    // Persist credentials on success
    await _credentialStore.save(username: user, password: pass);
    debugPrint('[PtitSyncService] Logged in: ${session.studentCode} (${session.studentName})');
    onProgress('Đăng nhập thành công: ${session.studentName}', 0.15);

    // Step 2: Get current semester
    onProgress('Đang xác định học kỳ hiện tại…', 0.20);
    final hocKy = await _apiClient.fetchCurrentSemester(session);
    debugPrint('[PtitSyncService] Current semester: $hocKy');
    onProgress('Học kỳ $hocKy – đang tải toàn bộ thời khóa biểu…', 0.30);

    // Step 3: Fetch full semester TKB
    final allClasses = await _apiClient.fetchSemesterTkb(
      session: session,
      hocKy: hocKy,
    );

    debugPrint('[PtitSyncService] Fetched ${allClasses.length} lessons');

    if (allClasses.isEmpty) {
      onProgress('Không tìm thấy buổi học nào trong học kỳ $hocKy.', 1.0);
      return 0;
    }

    onProgress('Đang ghi ${allClasses.length} buổi học vào lịch…', 0.70);

    // Step 4: Write to device calendar
    final written = await _calendarWriter.writeAll(
      calendarId: targetCalendarId,
      classes: allClasses,
    );

    onProgress(
      'Hoàn tất! Đã đồng bộ $written/${allClasses.length} buổi học.',
      1.0,
    );

    return written;
  }

  // ---------------------------------------------------------------------------
  // Calendar helpers for UI
  // ---------------------------------------------------------------------------

  Future<List<CalendarAccount>> getWritableCalendars() async {
    try {
      final hasPerms = await _calendarPlugin.hasPermissions();
      if (hasPerms.data != true) {
        await _calendarPlugin.requestPermissions();
      }
      final result = await _calendarPlugin.retrieveCalendars();
      if (!result.isSuccess || result.data == null) return [];
      return result.data!
          .where((c) => c.id != null && c.name != null && !(c.isReadOnly ?? false))
          .map((c) => CalendarAccount(
                id: c.id!,
                name: c.name!,
                accountName: c.accountName,
                accountType: c.accountType,
                isDefault: c.isDefault ?? false,
                color: c.color,
              ))
          .toList();
    } catch (e) {
      debugPrint('[PtitSyncService] getWritableCalendars error: $e');
      return [];
    }
  }

  Future<bool> hasCredentials() => _credentialStore.hasCredentials();
  Future<void> clearCredentials() => _credentialStore.clear();
}
