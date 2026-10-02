import 'package:autozoom/app/app.dart';
import 'package:autozoom/core/models/class_session.dart';
import 'package:autozoom/core/models/zoom_meeting.dart';
import 'package:autozoom/features/home/home_controller.dart';
import 'package:autozoom/features/home/home_screen.dart';
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
    required bool autoJoin,
  }) async {}
}

Widget _app(SharedPreferences prefs, List<ClassSession> classes) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      calendarServiceProvider.overrideWithValue(
        MockCalendarService(
          mockClasses: classes,
          mockCalendars: [const CalendarAccount(id: 'cal_1', name: 'School')],
        ),
      ),
      notificationServiceProvider.overrideWithValue(MockNotificationService()),
    ],
    child: const AutoZoomApp(),
  );
}

void main() {
  test('formatMeetingId groups digits like Zoom', () {
    expect(formatMeetingId('123456789'), '123 456 789');
    expect(formatMeetingId('1234567890'), '123 456 7890');
    expect(formatMeetingId('123 4567-8901'), '123 4567 8901');
    expect(formatMeetingId('12345'), '12345');
  });

  test('dayLabel and countdownLabel', () {
    final now = DateTime(2026, 10, 1, 9, 0); // Thursday
    expect(dayLabel(DateTime(2026, 10, 1, 23), now), 'Hôm nay');
    expect(dayLabel(DateTime(2026, 10, 2, 7), now), 'Ngày mai');
    expect(dayLabel(DateTime(2026, 10, 3), now), 'Thứ 7, 03/10');
    expect(dayLabel(DateTime(2026, 10, 4), now), 'Chủ nhật, 04/10');

    DateTime at(int h, int m) => DateTime(2026, 10, 1, h, m);
    expect(countdownLabel(at(9, 12), at(11, 0), now), 'Bắt đầu sau 12 phút');
    expect(
        countdownLabel(at(10, 30), at(12, 0), now), 'Bắt đầu sau 1 giờ 30 phút');
    expect(
      countdownLabel(
          at(9, 0), at(10, 0), now.subtract(const Duration(seconds: 30))),
      'Sắp bắt đầu',
    );
    expect(countdownLabel(at(8, 0), at(10, 0), now), 'Đang diễn ra · còn 1 giờ');
    expect(
      countdownLabel(DateTime(2026, 10, 4, 9), DateTime(2026, 10, 4, 11), now),
      'Bắt đầu sau 3 ngày',
    );
  });

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
            autoJoin: true,
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
    expect(find.text('ID: 123 456 789'), findsOneWidget);
    expect(find.text('Có mật khẩu'), findsOneWidget);
    expect(find.textContaining('pass123'), findsNothing);
    expect(find.textContaining('Tự vào lúc'), findsOneWidget);

    await tester.tap(find.text('Tham gia Zoom'));
    await tester.pumpAndSettle();

    expect(joinTapped, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('ClassSessionCard shows an error SnackBar when Zoom fails to open',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final session = ClassSession(
      id: 'session_2',
      calendarId: 'cal_school',
      title: 'Toán rời rạc',
      startTime: now.add(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 2)),
      zoom: const ZoomMeeting(meetingId: '12345678901'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClassSessionCard(
            session: session,
            onJoinTap: (_) async => LaunchResult.failed('Không mở được Zoom.'),
          ),
        ),
      ),
    );

    expect(find.text('ID: 123 4567 8901'), findsOneWidget);
    expect(find.text('Có mật khẩu'), findsNothing);
    expect(find.textContaining('Tự vào lúc'), findsNothing);

    await tester.tap(find.text('Tham gia Zoom'));
    await tester.pumpAndSettle();

    expect(find.text('Không mở được Zoom.'), findsOneWidget);
    expect(find.text('Sao chép ID'), findsOneWidget);
  });

  testWidgets(
      'HomeScreen shows the next class as hero and groups the rest by day',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final later = now.add(const Duration(days: 2));
    final mockClasses = [
      ClassSession(
        id: 'session_1',
        calendarId: 'cal_1',
        calendarName: 'School',
        title: 'Cơ sở dữ liệu nâng cao',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now.add(const Duration(hours: 1)),
        zoom: const ZoomMeeting(meetingId: '98765432101'),
      ),
      ClassSession(
        id: 'session_2',
        calendarId: 'cal_1',
        calendarName: 'School',
        title: 'Mạng máy tính',
        startTime: later,
        endTime: later.add(const Duration(hours: 2)),
        zoom: const ZoomMeeting(meetingId: '1122334455'),
      ),
    ];

    await tester.pumpWidget(_app(prefs, mockClasses));
    await tester.pumpAndSettle();

    expect(find.text('AutoZoom'), findsOneWidget);
    // Hero: ongoing class with live countdown and the big join button.
    expect(find.text('ĐANG DIỄN RA'), findsOneWidget);
    expect(find.text('Cơ sở dữ liệu nâng cao'), findsOneWidget);
    expect(find.textContaining('Đang diễn ra · còn'), findsOneWidget);
    expect(find.text('Vào Zoom ngay'), findsOneWidget);
    // Rest of the list, under a day header.
    expect(find.text(dayLabel(later, now)), findsOneWidget);
    expect(find.text('Mạng máy tính'), findsOneWidget);
    expect(find.text('Tham gia Zoom'), findsOneWidget);
    expect(find.text('7 ngày'), findsOneWidget);
    expect(find.text('15 ngày'), findsOneWidget);
    expect(find.text('30 ngày'), findsOneWidget);
  });

  testWidgets(
      'HomeScreen filter bar switches 7, 15, 30 days and updates the list',
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
        // Outside the 7-day filter, inside the 15-day one.
        startTime: now.add(const Duration(days: 10)),
        endTime: now.add(const Duration(days: 10, hours: 2)),
        zoom: const ZoomMeeting(meetingId: '1122334455'),
      ),
    ];

    await tester.pumpWidget(_app(prefs, mockClasses));
    await tester.pumpAndSettle();

    // 7 days: nothing to show yet, with a way out.
    expect(find.text('Mạng máy tính'), findsNothing);
    expect(
        find.text('Không còn lớp Zoom nào trong 7 ngày tới'), findsOneWidget);
    expect(find.text('Đồng bộ TKB PTIT'), findsOneWidget);

    await tester.tap(find.text('15 ngày'));
    await tester.pumpAndSettle();

    expect(find.text('Mạng máy tính'), findsOneWidget);
    expect(find.text('Bắt đầu sau 10 ngày'), findsOneWidget);
    expect(prefs.getInt('dashboard_filter_days'), 15);

    await tester.tap(find.text('30 ngày'));
    await tester.pumpAndSettle();

    expect(find.text('Mạng máy tính'), findsOneWidget);
    expect(prefs.getInt('dashboard_filter_days'), 30);
  });
}
