import '../constants/app_constants.dart';

/// User preferences stored in SharedPreferences.
/// ponytail: Kept minimal and strictly decoupled from business logic.
class AppSettings {
  final Set<String> selectedCalendarIds;
  final int reminderMinutes;
  final bool hasPromptedCalendarSelection;

  const AppSettings({
    this.selectedCalendarIds = const {},
    this.reminderMinutes = AppConstants.defaultReminderMinutes,
    this.hasPromptedCalendarSelection = false,
  });

  AppSettings copyWith({
    Set<String>? selectedCalendarIds,
    int? reminderMinutes,
    bool? hasPromptedCalendarSelection,
  }) {
    return AppSettings(
      selectedCalendarIds: selectedCalendarIds ?? this.selectedCalendarIds,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      hasPromptedCalendarSelection:
          hasPromptedCalendarSelection ?? this.hasPromptedCalendarSelection,
    );
  }

  Map<String, dynamic> toJson() => {
        'selectedCalendarIds': selectedCalendarIds.toList(),
        'reminderMinutes': reminderMinutes,
        'hasPromptedCalendarSelection': hasPromptedCalendarSelection,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        selectedCalendarIds:
            (json['selectedCalendarIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toSet() ??
                const {},
        reminderMinutes: json['reminderMinutes'] as int? ??
            AppConstants.defaultReminderMinutes,
        hasPromptedCalendarSelection:
            json['hasPromptedCalendarSelection'] as bool? ?? false,
      );
}
