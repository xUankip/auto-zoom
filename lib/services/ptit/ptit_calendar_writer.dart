import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'ptit_models.dart';

/// Creates / updates calendar events on the device from a list of [PtitClass].
///
/// Timezone strategy: PTIT is a Vietnamese university → always use Asia/Ho_Chi_Minh.
/// The `ngay_hoc` from API is a naive local date ("2026-09-21T00:00:00") without
/// timezone suffix. We extract the date components and combine with period times
/// using Asia/Ho_Chi_Minh so the event appears at the correct local time in iOS/Android Calendar.
class PtitCalendarWriter {
  final DeviceCalendarPlugin _plugin;

  PtitCalendarWriter({DeviceCalendarPlugin? plugin})
      : _plugin = plugin ?? DeviceCalendarPlugin();

  /// Writes [classes] into [calendarId].
  /// Returns the number of events successfully created/updated.
  Future<int> writeAll({
    required String calendarId,
    required List<PtitClass> classes,
  }) async {
    // Ensure timezone data is loaded before writing.
    // This is safe to call multiple times – it's a no-op after first init.
    _ensureTimezone();

    int count = 0;

    for (final cls in classes) {
      try {
        final event = _buildEvent(calendarId, cls);
        if (event == null) {
          debugPrint('[PtitCalendarWriter] Skipping (bad date/period): $cls');
          continue;
        }
        final result = await _plugin.createOrUpdateEvent(event);
        if (result?.isSuccess == true) {
          count++;
          debugPrint(
            '[PtitCalendarWriter] ✅ ${cls.subjectName} '
            '${cls.ngayHoc.substring(0, 10)} t${cls.startPeriod}',
          );
        } else {
          debugPrint(
            '[PtitCalendarWriter] ❌ ${cls.subjectName}: '
            '${result?.errors.map((e) => e.errorMessage).join(", ")}',
          );
        }
      } catch (e, stack) {
        debugPrint('[PtitCalendarWriter] Error on ${cls.subjectName}: $e\n$stack');
      }
    }

    return count;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  static bool _tzInitialized = false;

  static void _ensureTimezone() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }

  Event? _buildEvent(String calendarId, PtitClass cls) {
    // Parse ngay_hoc: API returns "2026-09-21T00:00:00" (naive local date, no TZ suffix).
    // We only need the date component – time comes from the period table.
    final date = cls.date;
    if (date == null) return null;

    final startTimes = kPtitPeriodStart[cls.startPeriod];
    final endTimes = kPtitPeriodEnd[cls.endPeriod];
    if (startTimes == null || endTimes == null) {
      debugPrint(
        '[PtitCalendarWriter] Unknown period ${cls.startPeriod}-${cls.endPeriod} '
        'for ${cls.subjectName}',
      );
      return null;
    }

    // Use Asia/Ho_Chi_Minh explicitly – never rely on tz.local which may be UTC.
    final vnLocation = tz.getLocation('Asia/Ho_Chi_Minh');

    final startDt = tz.TZDateTime(
      vnLocation,
      date.year, date.month, date.day,
      startTimes[0], startTimes[1],
    );
    final endDt = tz.TZDateTime(
      vnLocation,
      date.year, date.month, date.day,
      endTimes[0], endTimes[1],
    );

    debugPrint(
      '[PtitCalendarWriter] Building: ${cls.subjectName} '
      '${date.year}-${date.month.toString().padLeft(2,"0")}-${date.day.toString().padLeft(2,"0")} '
      '${startTimes[0]}:${startTimes[1].toString().padLeft(2,"0")}'
      '-${endTimes[0]}:${endTimes[1].toString().padLeft(2,"0")} VN',
    );

    return Event(calendarId)
      ..title = cls.subjectName.isNotEmpty ? cls.subjectName : cls.subjectCode
      ..location = cls.room
      ..description = _buildDescription(cls)
      ..start = startDt
      ..end = endDt;
  }

  String _buildDescription(PtitClass cls) {
    final parts = <String>[];
    if (cls.subjectCode.isNotEmpty) parts.add('Mã môn: ${cls.subjectCode}');
    if (cls.tenLop.isNotEmpty) parts.add('Lớp: ${cls.tenLop}');
    if (cls.lecturer.isNotEmpty) parts.add('GV: ${cls.lecturer}');
    if (cls.room.isNotEmpty) parts.add('Phòng: ${cls.room}');
    parts.add('Tiết ${cls.startPeriod} → ${cls.endPeriod}');
    // Include Zoom link in description so AutoZoom parser can extract it.
    if (cls.linkHocOnline != null) {
      parts.add(cls.linkHocOnline!);
    }
    return parts.join('\n');
  }
}
