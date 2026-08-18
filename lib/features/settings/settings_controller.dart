import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_settings.dart';

final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsController(prefs);
});

class SettingsController extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  SettingsController(this._prefs) : super(const AppSettings()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final savedCalendarIds =
        _prefs.getStringList(AppConstants.keySelectedCalendarIds)?.toSet() ??
            const {};
    final savedReminder =
        _prefs.getInt(AppConstants.keyReminderMinutes) ??
            AppConstants.defaultReminderMinutes;
    final hasPrompted =
        _prefs.getBool(AppConstants.keyHasSeenOnboarding) ?? false;

    if (!mounted) return;
    state = AppSettings(
      selectedCalendarIds: savedCalendarIds,
      reminderMinutes: savedReminder,
      hasPromptedCalendarSelection: hasPrompted,
    );
  }

  Future<void> toggleCalendar(String calendarId) async {
    final current = Set<String>.from(state.selectedCalendarIds);
    if (current.contains(calendarId)) {
      current.remove(calendarId);
    } else {
      current.add(calendarId);
    }
    if (mounted) {
      state = state.copyWith(selectedCalendarIds: current);
    }
    await _prefs.setStringList(
      AppConstants.keySelectedCalendarIds,
      current.toList(),
    );
  }

  Future<void> selectAllCalendars(List<String> allIds) async {
    final current = Set<String>.from(allIds);
    if (mounted) {
      state = state.copyWith(selectedCalendarIds: current);
    }
    await _prefs.setStringList(
      AppConstants.keySelectedCalendarIds,
      current.toList(),
    );
  }

  Future<void> deselectAllCalendars() async {
    if (mounted) {
      state = state.copyWith(selectedCalendarIds: const {});
    }
    await _prefs.setStringList(
      AppConstants.keySelectedCalendarIds,
      [],
    );
  }

  Future<void> setReminderMinutes(int minutes) async {
    if (mounted) {
      state = state.copyWith(reminderMinutes: minutes);
    }
    await _prefs.setInt(AppConstants.keyReminderMinutes, minutes);
  }

  Future<void> markOnboardingComplete() async {
    if (mounted) {
      state = state.copyWith(hasPromptedCalendarSelection: true);
    }
    await _prefs.setBool(AppConstants.keyHasSeenOnboarding, true);
  }
}
