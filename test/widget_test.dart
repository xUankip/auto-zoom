import 'package:autozoom/app/app.dart';
import 'package:autozoom/core/models/class_session.dart';
import 'package:autozoom/core/models/zoom_meeting.dart';
import 'package:autozoom/features/home/home_controller.dart';
import 'package:autozoom/features/home/widgets/class_session_card.dart';
import 'package:autozoom/features/settings/settings_controller.dart';
import 'package:autozoom/services/calendar/calendar_service.dart';
import 'package:autozoom/services/meetings/meeting_launcher.dart';
import 'package:autozoom/services/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCalendarService implements CalendarService {
  final List<ClassSession> mockClasses;
  final List<CalendarAccount> mockCalendars;

  MockCalendarService({
    this.mockClasses = const [],
    this.mockCalendars = const [],
  });

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<List<CalendarAccount>> getCalendars() async => mockCalendars;

  @override
  Future<List<ClassSession>> getUpcomingClasses({
    Set<String> selectedCalendarIds = const {},
    DateTime? startTime,
    DateTime? endTime,
  }) async =>
      mockClasses;
}

class MockNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> reconcile({
    required List<ClassSession> upcomingClasses,
    required int reminderMinutes,
  }) async {}
}

void main() {
  testWidgets('ClassSessionCard renders details and triggers join',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final session = ClassSession(
      id: 'session_1',
      calendarId: 'cal_school',
      calendarName: 'School',
      title: 'Lập trình Mobile',
      startTime: now.add(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 3)),
      zoom: const ZoomMeeting(
        meetingId: '123456789',
        passcode: 'pass123',
        joinUrl: 'https://zoom.us/j/123456789?pwd=pass123',
      ),
    );

    bool joinTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassSessionCard(
            session: session,
            onJoinTap: (s) async {
              joinTapped = true;
              return LaunchResult.appLaunched(s.zoom.computedUrl!);
            },
          ),
        ),
      ),
    );

    expect(find.text('Lập trình Mobile'), findsOneWidget);
    expect(find.text('School'), findsOneWidget);
    expect(find.text('Tham gia Zoom'), findsOneWidget);
    expect(find.text('ID: 123456789'), findsOneWidget);

    await tester.tap(find.text('Tham gia Zoom'));
    await tester.pumpAndSettle();

    expect(joinTapped, isTrue);
  });

  testWidgets('HomeScreen displays class list when calendar has sessions',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final mockClasses = [
      ClassSession(
        id: 'session_1',
        calendarId: 'cal_1',
        calendarName: 'School',
        title: 'Cơ sở dữ liệu nâng cao',
        startTime: DateTime(now.year, now.month, now.day, 14, 0),
        endTime: DateTime(now.year, now.month, now.day, 16, 0),
        zoom: const ZoomMeeting(meetingId: '98765432101'),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          calendarServiceProvider.overrideWithValue(
            MockCalendarService(
              mockClasses: mockClasses,
              mockCalendars: [
                const CalendarAccount(id: 'cal_1', name: 'School'),
              ],
            ),
          ),
          notificationServiceProvider.overrideWithValue(
            MockNotificationService(),
          ),
        ],
        child: const AutoZoomApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AutoZoom'), findsOneWidget);
    expect(find.text('Cơ sở dữ liệu nâng cao'), findsOneWidget);
    expect(find.text('HÔM NAY'), findsOneWidget);
    expect(find.text('7 ngày'), findsOneWidget);
    expect(find.text('15 ngày'), findsOneWidget);
    expect(find.text('30 ngày'), findsOneWidget);
  });

  testWidgets('HomeScreen filter bar allows switching 7, 15, 30 days and updates header',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final mockClasses = [
      ClassSession(
        id: 'session_future',
        calendarId: 'cal_1',
        calendarName: 'School',
        title: 'Mạng máy tính',
        startTime: now.add(const Duration(days: 10)),
        endTime: now.add(const Duration(days: 10, hours: 2)),
        zoom: const ZoomMeeting(meetingId: '1122334455'),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          calendarServiceProvider.overrideWithValue(
            MockCalendarService(
              mockClasses: mockClasses,
              mockCalendars: [
                const CalendarAccount(id: 'cal_1', name: 'School'),
              ],
            ),
          ),
          notificationServiceProvider.overrideWithValue(
            MockNotificationService(),
          ),
        ],
        child: const AutoZoomApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Initially 7 days filter is active, header shows "7 NGÀY TỚI"
    expect(find.text('7 NGÀY TỚI'), findsOneWidget);

    // Switch to 15 days
    await tester.tap(find.text('15 ngày'));
    await tester.pumpAndSettle();

    expect(find.text('15 NGÀY TỚI'), findsOneWidget);
    expect(prefs.getInt('dashboard_filter_days'), 15);

    // Switch to 30 days
    await tester.tap(find.text('30 ngày'));
    await tester.pumpAndSettle();

    expect(find.text('30 NGÀY TỚI'), findsOneWidget);
    expect(prefs.getInt('dashboard_filter_days'), 30);
  });
}
