import 'package:autozoom/core/models/class_session.dart';
import 'package:autozoom/core/models/zoom_meeting.dart';
import 'package:autozoom/core/utils/deterministic_hash.dart';
import 'package:autozoom/services/notifications/notification_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeterministicHash Rigorous Tests', () {
    test('same eventId + same startTime produces EXACT same notificationId', () {
      final time = DateTime(2026, 8, 18, 8, 0);
      final id1 = DeterministicHash.forEvent('event_alpha', time);
      final id2 = DeterministicHash.forEvent('event_alpha', time);
      expect(id1, equals(id2));
    });

    test('different eventId produces different notificationId', () {
      final time = DateTime(2026, 8, 18, 8, 0);
      final id1 = DeterministicHash.forEvent('event_alpha', time);
      final id2 = DeterministicHash.forEvent('event_beta', time);
      expect(id1, isNot(equals(id2)));
    });

    test('same eventId + changed startTime produces different notificationId', () {
      final time1 = DateTime(2026, 8, 18, 8, 0);
      final time2 = DateTime(2026, 8, 18, 9, 0);
      final id1 = DeterministicHash.forEvent('event_alpha', time1);
      final id2 = DeterministicHash.forEvent('event_alpha', time2);
      expect(id1, isNot(equals(id2)));
    });

    test('realistic collision test across 5,000 distinct event+time pairs', () {
      final seenIds = <int>{};
      final baseTime = DateTime(2026, 8, 18, 8, 0);

      for (var i = 0; i < 5000; i++) {
        final eventId = 'class_event_$i';
        final eventTime = baseTime.add(Duration(minutes: i * 30));
        final hashId = DeterministicHash.forEvent(eventId, eventTime);

        expect(
          seenIds.contains(hashId),
          isFalse,
          reason: 'Collision detected for event $eventId at index $i (hash: $hashId)',
        );
        seenIds.add(hashId);
      }

      expect(seenIds.length, 5000);
    });
  });

  group('Reconciliation Lifecycle Simulation Tests', () {
    final fixedNow = DateTime(2026, 8, 18, 6, 0); // 06:00 AM

    test('Lifecycle: Create -> Reschedule -> Delete', () {
      // Step 1: Initial event at 08:00 (reminder at 07:50)
      final sessionV1 = ClassSession(
        id: 'event_mobile_101',
        calendarId: 'cal_school',
        title: 'Lập trình Mobile',
        startTime: DateTime(2026, 8, 18, 8, 0),
        endTime: DateTime(2026, 8, 18, 10, 0),
        zoom: const ZoomMeeting(
          meetingId: '123456789',
          passcode: 'abc123',
        ),
      );

      final scheduleV1 = NotificationReconciler.buildDesiredSchedule(
        classes: [sessionV1],
        reminderMinutes: 10,
        currentTime: fixedNow,
      );

      expect(scheduleV1.length, 1);
      final initialId = scheduleV1.first.id;
      expect(scheduleV1.first.scheduledTime, DateTime(2026, 8, 18, 7, 50));

      // Simulate current active OS scheduled notification IDs
      final activeScheduledIds = {initialId};

      // Step 2: Teacher moves class from 08:00 -> 09:00 (reminder at 08:50)
      final sessionV2 = ClassSession(
        id: 'event_mobile_101',
        calendarId: 'cal_school',
        title: 'Lập trình Mobile',
        startTime: DateTime(2026, 8, 18, 9, 0),
        endTime: DateTime(2026, 8, 18, 11, 0),
        zoom: const ZoomMeeting(
          meetingId: '123456789',
          passcode: 'abc123',
        ),
      );

      final scheduleV2 = NotificationReconciler.buildDesiredSchedule(
        classes: [sessionV2],
        reminderMinutes: 10,
        currentTime: fixedNow,
      );

      expect(scheduleV2.length, 1);
      final updatedId = scheduleV2.first.id;
      expect(scheduleV2.first.scheduledTime, DateTime(2026, 8, 18, 8, 50));
      expect(updatedId, isNot(equals(initialId)));

      // Reconciler checks which old notifications must be cancelled
      final desiredIdsV2 = scheduleV2.map((e) => e.id).toSet();
      final idsToCancel = activeScheduledIds.difference(desiredIdsV2);
      final idsToSchedule = desiredIdsV2.difference(activeScheduledIds);

      expect(idsToCancel, contains(initialId)); // 07:50 is cancelled!
      expect(idsToSchedule, contains(updatedId)); // 08:50 is scheduled!

      // Update active simulated set
      activeScheduledIds.removeAll(idsToCancel);
      activeScheduledIds.addAll(idsToSchedule);
      expect(activeScheduledIds, equals({updatedId}));

      // Step 3: Event is deleted from Calendar
      final scheduleV3 = NotificationReconciler.buildDesiredSchedule(
        classes: [], // Empty list after deletion
        reminderMinutes: 10,
        currentTime: fixedNow,
      );

      expect(scheduleV3, isEmpty);

      final desiredIdsV3 = scheduleV3.map((e) => e.id).toSet();
      final idsToCancelOnDelete = activeScheduledIds.difference(desiredIdsV3);
      expect(idsToCancelOnDelete, contains(updatedId)); // 08:50 is cancelled!
    });
  });
}
