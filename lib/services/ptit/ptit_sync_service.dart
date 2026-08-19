import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';

import '../calendar/calendar_service.dart';
import 'ptit_api_client.dart';
import 'ptit_calendar_writer.dart';
import 'ptit_credential_store.dart';
import 'ptit_models.dart';

/// Orchestrates the full PTIT → Device Calendar sync.
///
/// Flow:
///   1. Load credentials from secure store (or accept them directly)
///   2. Login → get JWT session
///   3. Scan semester weeks until _emptyWeekStop consecutive empties
///   4. Write all classes to the target device calendar
class PtitSyncService {
  static const _maxWeeks = 30;
  static const _emptyWeekStop = 3;

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

  /// Run a full sync. [onProgress] receives human-readable status + 0..1 progress.
  ///
  /// Returns the count of events written. Throws [PtitAuthException] on login failure.
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

    onProgress('Đang đăng nhập vào hệ thống PTIT…', 0.05);
    final session = await _apiClient.login(username: user, password: pass);

    // Persist on success
    await _credentialStore.save(username: user, password: pass);

    debugPrint('[PtitSyncService] Logged in as ${session.studentCode}');
    onProgress('Đăng nhập thành công: ${session.studentName}', 0.10);

    // Scan weeks
    final List<PtitClass> allClasses = [];
    int emptyStreak = 0;

    for (int week = 1; week <= _maxWeeks; week++) {
      try {
        final weekClasses = await _apiClient.fetchWeek(
          session: session,
          weekIndex: week,
        );

        if (weekClasses.isEmpty) {
          emptyStreak++;
          debugPrint(
            '[PtitSyncService] Week $week: empty (streak=$emptyStreak)',
          );
          if (emptyStreak >= _emptyWeekStop) break;
        } else {
          emptyStreak = 0;
          allClasses.addAll(weekClasses);
          debugPrint('[PtitSyncService] Week $week: ${weekClasses.length} classes');
        }

        final progress = 0.10 + (week / _maxWeeks) * 0.65;
        onProgress(
          'Tuần $week: ${weekClasses.isEmpty ? "trống" : "${weekClasses.length} tiết"}',
          progress.clamp(0.0, 0.75),
        );
      } catch (e) {
        debugPrint('[PtitSyncService] Error on week $week: $e');
        // Non-fatal – continue scanning
      }
    }

    debugPrint('[PtitSyncService] Total: ${allClasses.length} classes to write');

    if (allClasses.isEmpty) {
      onProgress('Không tìm thấy lịch học nào trong học kỳ.', 1.0);
      return 0;
    }

    onProgress('Đang ghi ${allClasses.length} buổi học vào lịch…', 0.80);

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
