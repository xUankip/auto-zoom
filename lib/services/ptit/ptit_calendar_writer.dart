import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'ptit_models.dart';

/// Creates / updates calendar events on the device from a list of [PtitClass].
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
          debugPrint('[PtitCalendarWriter] ✅ ${cls.subjectName} ${cls.ngayHoc}');
        } else {
          debugPrint(
            '[PtitCalendarWriter] ❌ ${cls.subjectName}: '
            '${result?.errors.map((e) => e.errorMessage).join(", ")}',
          );
        }
      } catch (e) {
        debugPrint('[PtitCalendarWriter] Error: $e');
      }
    }

    return count;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Event? _buildEvent(String calendarId, PtitClass cls) {
    final date = cls.date;
    if (date == null) return null;

    final startTimes = kPtitPeriodStart[cls.startPeriod];
    final endTimes = kPtitPeriodEnd[cls.endPeriod];
    if (startTimes == null || endTimes == null) return null;

    final location = tz.local;

    final startDt = tz.TZDateTime(
      location,
      date.year, date.month, date.day,
      startTimes[0], startTimes[1],
    );
    final endDt = tz.TZDateTime(
      location,
      date.year, date.month, date.day,
      endTimes[0], endTimes[1],
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
    parts.add('Tiết ${cls.startPeriod} - ${cls.endPeriod}');
    // Include zoom link in description so AutoZoom parser can find it
    if (cls.linkHocOnline != null) {
      parts.add('Zoom: ${cls.linkHocOnline}');
    }
    return parts.join('\n');
  }
}
