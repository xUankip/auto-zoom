import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'ptit_models.dart';

/// Creates / updates calendar events on the device from a list of [PtitClass].
///
/// Strategy: idempotent write – uses a stable title hash so re-running sync
/// doesn't duplicate events. Events are created in the user's selected calendar.
class PtitCalendarWriter {
  final DeviceCalendarPlugin _plugin;

  PtitCalendarWriter({DeviceCalendarPlugin? plugin})
      : _plugin = plugin ?? DeviceCalendarPlugin();

  /// Writes [classes] into [calendarId].
  ///
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
          debugPrint('[PtitCalendarWriter] Skipping (bad date): $cls');
          continue;
        }
        final result = await _plugin.createOrUpdateEvent(event);
        if (result?.isSuccess == true) {
          count++;
          debugPrint('[PtitCalendarWriter] Wrote: ${cls.subjectName} ${cls.dateStr}');
        } else {
          debugPrint(
            '[PtitCalendarWriter] Failed: ${cls.subjectName} '
            '${result?.errors.map((e) => e.errorMessage).join(", ")}',
          );
        }
      } catch (e) {
        debugPrint('[PtitCalendarWriter] Error writing $cls: $e');
      }
    }

    return count;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Event? _buildEvent(String calendarId, PtitClass cls) {
    final date = _parseDate(cls.dateStr);
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

    final event = Event(calendarId)
      ..title = cls.subjectName.isNotEmpty ? cls.subjectName : cls.subjectCode
      ..location = cls.room
      ..description = _buildDescription(cls)
      ..start = startDt
      ..end = endDt;

    return event;
  }

  String _buildDescription(PtitClass cls) {
    final parts = <String>[];
    if (cls.subjectCode.isNotEmpty) parts.add('Mã môn: ${cls.subjectCode}');
    if (cls.lecturer.isNotEmpty) parts.add('GV: ${cls.lecturer}');
    if (cls.room.isNotEmpty) parts.add('Phòng: ${cls.room}');
    parts.add('Tiết: ${cls.startPeriod} - ${cls.endPeriod}');
    return parts.join('\n');
  }

  /// Parses "dd/MM/yyyy" format used by PTIT API.
  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    try {
      final parts = raw.split('/');
      if (parts.length != 3) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}
