import 'dart:convert';
import 'package:intl/intl.dart';

import '../../core/models/class_session.dart';

/// Single item representing a scheduled notification target.
class NotificationScheduleItem {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final String payloadJson;

  const NotificationScheduleItem({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    required this.payloadJson,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationScheduleItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          scheduledTime == other.scheduledTime;

  @override
  int get hashCode => Object.hash(id, scheduledTime);
}

/// Pure calculation engine for determining which notifications to schedule or reconcile.
/// ponytail: Pure functional logic makes it 100% testable without native mocking.
class NotificationReconciler {
  NotificationReconciler._();

  /// Computes the desired list of upcoming notifications from the provided [classes].
  /// Filters out any sessions whose scheduled reminder time is already in the past.
  static List<NotificationScheduleItem> buildDesiredSchedule({
    required List<ClassSession> classes,
    required int reminderMinutes,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final List<NotificationScheduleItem> items = [];

    final timeFormatter = DateFormat('HH:mm');

    for (final session in classes) {
      final scheduledTime = session.reminderTime(reminderMinutes);

      // Only schedule if the reminder time is in the future
      if (scheduledTime.isAfter(now)) {
        final id = session.notificationId(reminderMinutes);
        final title = '🔔 Sắp đến giờ học: ${session.title}';
        final body =
            'Bắt đầu lúc ${timeFormatter.format(session.startTime)}. Nhấn để tham gia Zoom ngay.';

        final payloadJson = jsonEncode(session.toNotificationPayload());

        items.add(
          NotificationScheduleItem(
            id: id,
            title: title,
            body: body,
            scheduledTime: scheduledTime,
            payloadJson: payloadJson,
          ),
        );
      }
    }

    return items;
  }
}
