import 'dart:convert';
import 'package:autozoom/core/models/class_session.dart';
import 'package:autozoom/core/models/zoom_meeting.dart';
import 'package:autozoom/core/utils/deterministic_hash.dart';
import 'package:autozoom/services/notifications/notification_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeterministicHash Tests', () {
    test('produces identical positive hash for same inputs', () {
      final now = DateTime(2026, 8, 18, 8, 0);
      final id1 = DeterministicHash.forEvent('event_123', now);
      final id2 = DeterministicHash.forEvent('event_123', now);
      expect(id1, equals(id2));
      expect(id1, isPositive);
    });

    test('produces different hashes for different events or times', () {
      final t1 = DateTime(2026, 8, 18, 8, 0);
      final t2 = DateTime(2026, 8, 18, 9, 0);
      final id1 = DeterministicHash.forEvent('event_123', t1);
      final id2 = DeterministicHash.forEvent('event_123', t2);
      final id3 = DeterministicHash.forEvent('event_456', t1);
      expect(id1, isNot(equals(id2)));
      expect(id1, isNot(equals(id3)));
    });
  });

  group('NotificationReconciler Tests', () {
    final fixedNow = DateTime(2026, 8, 18, 7, 0);

    test('builds schedule for upcoming future events', () {
      final session = ClassSession(
        id: 'class_01',
        calendarId: 'cal_school',
        title: 'Lập trình Mobile',
        startTime: DateTime(2026, 8, 18, 8, 0),
        endTime: DateTime(2026, 8, 18, 10, 0),
        zoom: const ZoomMeeting(
          meetingId: '123456789',
          passcode: 'secretPass',
          joinUrl: 'https://zoom.us/j/123456789?pwd=secretPass',
        ),
      );

      final items = NotificationReconciler.buildDesiredSchedule(
        classes: [session],
        reminderMinutes: 10,
        currentTime: fixedNow,
      );

      expect(items.length, 1);
      final item = items.first;
      expect(item.title, contains('Lập trình Mobile'));
      expect(item.body, contains('08:00'));
      // Verify passcode is NOT exposed in notification body/title
      expect(item.body.contains('secretPass'), isFalse);
      expect(item.title.contains('secretPass'), isFalse);
      expect(item.scheduledTime, DateTime(2026, 8, 18, 7, 50));

      // Verify payload has necessary info
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      expect(payload['eventId'], 'class_01');
      expect(payload['joinUrl'], 'https://zoom.us/j/123456789?pwd=secretPass');
    });

    test('ignores past reminder times', () {
      final pastSession = ClassSession(
        id: 'class_past',
        calendarId: 'cal_school',
        title: 'Lớp học đã qua',
        startTime: DateTime(2026, 8, 18, 6, 0),
        endTime: DateTime(2026, 8, 18, 7, 0),
        zoom: const ZoomMeeting(meetingId: '111222333'),
      );

      final items = NotificationReconciler.buildDesiredSchedule(
        classes: [pastSession],
        reminderMinutes: 10,
        currentTime: fixedNow,
      );

      expect(items, isEmpty);
    });
  });
}
