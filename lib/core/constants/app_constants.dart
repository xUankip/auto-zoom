// App-wide constants for AutoZoom
class AppConstants {
  AppConstants._();

  /// Rolling window duration for querying calendar events and scheduling notifications.
  /// poncho: Keeps memory footprint minimal while guaranteeing a full week of proactive reminders.
  static const Duration notificationScheduleWindow = Duration(days: 7);

  /// Default minutes before class to trigger local notification.
  static const int defaultReminderMinutes = 10;

  /// Available reminder offset options in minutes.
  static const List<int> reminderOptions = [5, 10, 15, 30];

  /// Shared Preferences Keys
  static const String keySelectedCalendarIds = 'selected_calendar_ids';
  static const String keyReminderMinutes = 'reminder_minutes';
  static const String keyHasSeenOnboarding = 'has_seen_onboarding';

  /// Notification Channel details for Android
  static const String notificationChannelId = 'autozoom_class_reminders';
  static const String notificationChannelName = 'Class Reminders';
  static const String notificationChannelDesc = 'Proactive reminders for upcoming Zoom classes';

  /// Notification Actions
  static const String actionJoin = 'ACTION_JOIN';
  static const String actionDismiss = 'ACTION_DISMISS';
}
