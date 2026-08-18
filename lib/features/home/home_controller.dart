import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/class_session.dart';
import '../../services/calendar/calendar_service.dart';
import '../../services/calendar/device_calendar_service.dart';
import '../../services/meetings/meeting_launcher.dart';
import '../../services/meetings/zoom_launcher.dart';
import '../../services/notifications/notification_service.dart';
import '../settings/settings_controller.dart';

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return DeviceCalendarService();
});

final meetingLauncherProvider = Provider<MeetingLauncher>((ref) {
  return const ZoomLauncher();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final launcher = ref.watch(meetingLauncherProvider);
  return NotificationService(meetingLauncher: launcher);
});

class HomeState {
  final bool isLoading;
  final bool hasCalendarPermission;
  final List<ClassSession> classes;
  final List<CalendarAccount> availableCalendars;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  const HomeState({
    this.isLoading = false,
    this.hasCalendarPermission = true,
    this.classes = const [],
    this.availableCalendars = const [],
    this.errorMessage,
    this.lastSyncedAt,
  });

  HomeState copyWith({
    bool? isLoading,
    bool? hasCalendarPermission,
    List<ClassSession>? classes,
    List<CalendarAccount>? availableCalendars,
    String? errorMessage,
    DateTime? lastSyncedAt,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      hasCalendarPermission:
          hasCalendarPermission ?? this.hasCalendarPermission,
      classes: classes ?? this.classes,
      availableCalendars: availableCalendars ?? this.availableCalendars,
      errorMessage: errorMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  /// Returns classes scheduled for today.
  List<ClassSession> get todayClasses {
    final now = DateTime.now();
    return classes.where((c) {
      return c.startTime.year == now.year &&
          c.startTime.month == now.month &&
          c.startTime.day == now.day;
    }).toList();
  }

  /// Returns classes scheduled for future days in the rolling window.
  List<ClassSession> get upcomingDaysClasses {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return classes.where((c) => c.startTime.isAfter(todayEnd)).toList();
  }
}

final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeState>((ref) {
  final calendarService = ref.watch(calendarServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final meetingLauncher = ref.watch(meetingLauncherProvider);
  final settingsController = ref.watch(settingsControllerProvider.notifier);

  return HomeController(
    calendarService: calendarService,
    notificationService: notificationService,
    meetingLauncher: meetingLauncher,
    settingsController: settingsController,
    ref: ref,
  );
});

class HomeController extends StateNotifier<HomeState> {
  final CalendarService calendarService;
  final NotificationService notificationService;
  final MeetingLauncher meetingLauncher;
  final SettingsController settingsController;
  final Ref ref;

  HomeController({
    required this.calendarService,
    required this.notificationService,
    required this.meetingLauncher,
    required this.settingsController,
    required this.ref,
  }) : super(const HomeState()) {
    initAndSync();
  }

  Future<void> initAndSync() async {
    await notificationService.initialize();
    if (!mounted) return;
    await syncCalendar();
  }

  /// Full reconciliation and sync flow.
  /// Triggered on: App start, App resume foreground, or User pull-to-refresh.
  Future<void> syncCalendar() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final hasPerm = await calendarService.hasPermissions();
      if (!mounted) return;

      if (!hasPerm) {
        state = state.copyWith(
          isLoading: false,
          hasCalendarPermission: false,
        );
        return;
      }

      final calendars = await calendarService.getCalendars();
      if (!mounted) return;

      final settings = ref.read(settingsControllerProvider);

      // Default: If user has never selected calendars, auto-select all
      Set<String> selectedIds = settings.selectedCalendarIds;
      if (selectedIds.isEmpty &&
          calendars.isNotEmpty &&
          !settings.hasPromptedCalendarSelection) {
        selectedIds = calendars.map((c) => c.id).toSet();
        await settingsController.selectAllCalendars(selectedIds.toList());
      }

      final upcomingClasses = await calendarService.getUpcomingClasses(
        selectedCalendarIds: selectedIds,
      );
      if (!mounted) return;

      // Reconcile and schedule notifications
      await notificationService.reconcile(
        upcomingClasses: upcomingClasses,
        reminderMinutes: settings.reminderMinutes,
      );
      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        hasCalendarPermission: true,
        availableCalendars: calendars,
        classes: upcomingClasses,
        lastSyncedAt: DateTime.now(),
      );

      debugPrint(
          '[HomeController] Synced ${upcomingClasses.length} Zoom classes successfully.');
    } catch (e) {
      debugPrint('[HomeController] Sync error: $e');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể đồng bộ lịch: $e',
      );
    }
  }

  /// Request permissions from OS.
  Future<void> requestPermissions() async {
    final granted = await calendarService.requestPermissions();
    await notificationService.requestPermissions();
    if (!mounted) return;

    if (granted) {
      await syncCalendar();
    } else {
      state = state.copyWith(hasCalendarPermission: false);
    }
  }

  /// Launches a Zoom meeting.
  Future<LaunchResult> launchMeeting(ClassSession session) async {
    return meetingLauncher.launch(session.zoom);
  }
}
