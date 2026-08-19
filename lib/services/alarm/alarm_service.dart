import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/foundation.dart';

import '../notifications/notification_reconciler.dart';

/// Callback type for handling alarm ringing event (e.g. displaying fullscreen UI).
typedef OnAlarmRingCallback = void Function(AlarmSettings alarmSettings);

/// Service managing hardware-silent-switch bypassing alarms on iOS & Android.
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  bool _isInitialized = false;
  StreamSubscription<AlarmSet>? _ringSubscription;
  OnAlarmRingCallback? onAlarmRing;

  /// Initializes the underlying alarm audio engine and event listeners.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Alarm.init();
      _ringSubscription = Alarm.ringing.listen((alarmSet) {
        for (final alarmSettings in alarmSet.alarms) {
          debugPrint(
              '[AlarmService] Alarm ringing: id=${alarmSettings.id}, time=${alarmSettings.dateTime}');
          if (onAlarmRing != null) {
            onAlarmRing!(alarmSettings);
          }
        }
      });
      _isInitialized = true;
      debugPrint('[AlarmService] Initialized successfully.');
    } catch (e) {
      debugPrint('[AlarmService] Initialization warning/error: $e');
    }
  }

  /// Schedules a single alarm for a class reminder.
  Future<void> scheduleAlarm({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    String? payloadJson,
  }) async {
    if (!_isInitialized) await initialize();

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: dateTime,
      assetAudioPath: 'assets/alarm.wav',
      volumeSettings: const VolumeSettings.fixed(
        volume: 1.0,
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Tắt chuông',
      ),
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: true,
      iOSBackgroundAudio: true,
      payload: payloadJson,
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('[AlarmService] Scheduled alarm id=$id for $dateTime');
    } catch (e) {
      debugPrint('[AlarmService] Error scheduling alarm id=$id: $e');
    }
  }

  /// Stops an active or ringing alarm by id.
  Future<void> stopAlarm(int id) async {
    try {
      await Alarm.stop(id);
      debugPrint('[AlarmService] Stopped alarm id=$id');
    } catch (e) {
      debugPrint('[AlarmService] Error stopping alarm id=$id: $e');
    }
  }

  /// Stops all active or ringing alarms.
  Future<void> stopAll() async {
    try {
      await Alarm.stopAll();
      debugPrint('[AlarmService] Stopped all alarms');
    } catch (e) {
      debugPrint('[AlarmService] Error stopping all alarms: $e');
    }
  }

  /// Reconciles currently registered alarms with the desired upcoming class schedule.
  Future<void> reconcileAlarms({
    required List<NotificationScheduleItem> desiredItems,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final desiredIds = desiredItems.map((e) => e.id).toSet();

      // 1. Get currently scheduled alarms
      final currentAlarms = await Alarm.getAlarms();

      // 2. Cancel alarms not in desired set
      for (final alarm in currentAlarms) {
        if (!desiredIds.contains(alarm.id)) {
          await Alarm.stop(alarm.id);
          debugPrint('[AlarmService] Cancelled stale alarm id: ${alarm.id}');
        }
      }

      // 3. Schedule all desired alarms
      for (final item in desiredItems) {
        // Check if already scheduled for exact time
        final existing =
            currentAlarms.where((a) => a.id == item.id).firstOrNull;
        if (existing != null &&
            existing.dateTime.isAtSameMomentAs(item.scheduledTime)) {
          continue; // Already correctly scheduled
        }

        await scheduleAlarm(
          id: item.id,
          dateTime: item.scheduledTime,
          title: item.title,
          body: item.body,
          payloadJson: item.payloadJson,
        );
      }
    } catch (e) {
      debugPrint('[AlarmService] Reconcile error: $e');
    }
  }


  /// Triggers a test alarm scheduled for 1 second in the future.
  Future<void> triggerTestAlarm() async {
    if (!_isInitialized) await initialize();

    final testTime = DateTime.now().add(const Duration(seconds: 1));
    await scheduleAlarm(
      id: 999998,
      dateTime: testTime,
      title: '🔔 Thử nghiệm chuông báo thức AutoZoom',
      body: 'Chuông báo thức chạy nền xuyên qua nút gạt Im lặng (Silent Switch)!',
    );
  }

  /// Disposes active subscriptions.
  void dispose() {
    _ringSubscription?.cancel();
    _ringSubscription = null;
  }
}
