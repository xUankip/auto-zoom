import '../utils/deterministic_hash.dart';
import 'zoom_meeting.dart';

/// Represents an identified school/work class session associated with Zoom credentials.
class ClassSession {
  final String id;
  final String calendarId;
  final String? calendarName;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? description;
  final ZoomMeeting zoom;

  const ClassSession({
    required this.id,
    required this.calendarId,
    this.calendarName,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    required this.zoom,
  });

  /// True if current time is between start and end.
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// True if class hasn't started yet.
  bool get isUpcoming => DateTime.now().isBefore(startTime);

  /// True if class has already ended.
  bool get isPast => DateTime.now().isAfter(endTime);

  /// Class duration in minutes.
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  /// Calculates the exact time the notification should fire based on reminder offset.
  DateTime reminderTime(int minutesBefore) =>
      startTime.subtract(Duration(minutes: minutesBefore));

  /// Deterministic integer ID for scheduling local notifications.
  int notificationId(int minutesBefore) =>
      DeterministicHash.forEvent(id, startTime);

  /// Immutable payload serialized to JSON for notifications.
  Map<String, dynamic> toNotificationPayload() => {
        'eventId': id,
        'title': title,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'joinUrl': zoom.computedUrl,
        'meetingId': zoom.meetingId,
        'deepLinkUrl': zoom.deepLinkUrl,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassSession &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          calendarId == other.calendarId &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => Object.hash(id, calendarId, startTime, endTime);

  @override
  String toString() =>
      'ClassSession(title: $title, start: $startTime, end: $endTime, zoom: $zoom)';
}
