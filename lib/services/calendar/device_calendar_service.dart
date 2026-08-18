import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/class_session.dart';
import '../../core/parser/zoom_parser.dart';
import 'calendar_service.dart';

/// Concrete implementation of [CalendarService] using device_calendar (EventKit on iOS & Calendar Provider on Android).
class DeviceCalendarService implements CalendarService {
  final DeviceCalendarPlugin _plugin;

  DeviceCalendarService({DeviceCalendarPlugin? plugin})
      : _plugin = plugin ?? DeviceCalendarPlugin();

  @override
  Future<bool> hasPermissions() async {
    try {
      final res = await _plugin.hasPermissions();
      return res.isSuccess && (res.data ?? false);
    } catch (e) {
      debugPrint('[DeviceCalendarService] hasPermissions error: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final res = await _plugin.requestPermissions();
      return res.isSuccess && (res.data ?? false);
    } catch (e) {
      debugPrint('[DeviceCalendarService] requestPermissions error: $e');
      return false;
    }
  }

  @override
  Future<List<CalendarAccount>> getCalendars() async {
    try {
      final res = await _plugin.retrieveCalendars();
      if (!res.isSuccess || res.data == null) {
        return [];
      }

      return res.data!
          .where((c) => c.id != null && c.name != null)
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
      debugPrint('[DeviceCalendarService] getCalendars error: $e');
      return [];
    }
  }

  @override
  Future<List<ClassSession>> getUpcomingClasses({
    Set<String> selectedCalendarIds = const {},
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final hasPerm = await hasPermissions();
    if (!hasPerm) {
      debugPrint('[DeviceCalendarService] Calendar permission not granted.');
      return [];
    }

    final now = DateTime.now();
    // Query from start of today (00:00:00) so ongoing/today's classes are not skipped
    final start = startTime ?? DateTime(now.year, now.month, now.day);
    final end = endTime ?? start.add(AppConstants.notificationScheduleWindow);

    final calendars = await getCalendars();
    if (calendars.isEmpty) {
      debugPrint('[DeviceCalendarService] No calendars found on device.');
      return [];
    }

    // If user filtered calendars, only query matching ones; otherwise query all
    final targetCalendars = selectedCalendarIds.isEmpty
        ? calendars
        : calendars.where((c) => selectedCalendarIds.contains(c.id)).toList();

    debugPrint(
        '[DeviceCalendarService] Querying ${targetCalendars.length}/${calendars.length} calendars from $start to $end');

    final List<ClassSession> results = [];

    for (final cal in targetCalendars) {
      try {
        final params = RetrieveEventsParams(
          startDate: start,
          endDate: end,
        );

        final eventsResult = await _plugin.retrieveEvents(cal.id, params);
        if (!eventsResult.isSuccess || eventsResult.data == null) {
          debugPrint(
              '[DeviceCalendarService] Retrieve failed for calendar ${cal.name}: ${eventsResult.errors.map((e) => e.errorMessage).join(", ")}');
          continue;
        }

        final rawEvents = eventsResult.data!;
        debugPrint(
            '[DeviceCalendarService] Calendar "${cal.name}" (${cal.id}) returned ${rawEvents.length} events.');

        for (final event in rawEvents) {
          final eventStart = event.start?.toLocal();
          final eventEnd = event.end?.toLocal();

          debugPrint(
              '  -> Event: "${event.title}", Start: $eventStart, End: $eventEnd, Location: "${event.location}", Desc: "${event.description}"');

          if (event.eventId == null || eventStart == null || eventEnd == null) {
            continue;
          }

          // Parse Zoom credentials
          final zoom = ZoomParser.parse(
            title: event.title,
            description: event.description,
            location: event.location,
          );

          debugPrint('     Zoom parsed: ${zoom?.meetingId} (url: ${zoom?.joinUrl})');

          // Only keep events with valid Zoom meeting details
          if (zoom != null) {
            results.add(
              ClassSession(
                id: event.eventId!,
                calendarId: cal.id,
                calendarName: cal.name,
                title: (event.title?.trim().isNotEmpty ?? false)
                    ? event.title!.trim()
                    : 'Lớp học Zoom',
                startTime: eventStart,
                endTime: eventEnd,
                location: event.location,
                description: event.description,
                zoom: zoom,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint(
            '[DeviceCalendarService] Error querying calendar ${cal.name}: $e');
      }
    }

    // Sort chronologically
    results.sort((a, b) => a.startTime.compareTo(b.startTime));
    return results;
  }
}
