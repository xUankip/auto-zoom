import '../../core/models/class_session.dart';

/// Lightweight representation of a user's calendar account.
class CalendarAccount {
  final String id;
  final String name;
  final String? accountName;
  final String? accountType;
  final bool isDefault;
  final int? color;

  const CalendarAccount({
    required this.id,
    required this.name,
    this.accountName,
    this.accountType,
    this.isDefault = false,
    this.color,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CalendarAccount(id: $id, name: $name)';
}

/// Abstract contract for reading system calendars and extracting Zoom class sessions.
abstract class CalendarService {
  /// Checks if calendar permissions have been granted by the OS.
  Future<bool> hasPermissions();

  /// Requests calendar permissions from the OS (Full Access on iOS 17+).
  Future<bool> requestPermissions();

  /// Retrieves all calendars accessible on the device.
  Future<List<CalendarAccount>> getCalendars();

  /// Queries calendar events in the given window, parses Zoom details,
  /// and returns only events containing valid Zoom meetings as [ClassSession] objects.
  /// If [selectedCalendarIds] is empty, defaults to querying all available calendars.
  Future<List<ClassSession>> getUpcomingClasses({
    Set<String> selectedCalendarIds = const {},
    DateTime? startTime,
    DateTime? endTime,
  });
}
