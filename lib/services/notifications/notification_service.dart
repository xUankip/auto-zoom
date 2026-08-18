import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/app_constants.dart';
import '../../core/models/class_session.dart';
import '../../core/models/zoom_meeting.dart';
import '../meetings/meeting_launcher.dart';
import '../meetings/zoom_launcher.dart';
import 'notification_reconciler.dart';

/// Callback type for handling meeting launches triggered from notifications.
typedef OnNotificationMeetingLaunch = void Function(ZoomMeeting meeting);

/// Manages local notification scheduling, interactive actions, and Zoom meeting auto-launching.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final MeetingLauncher _meetingLauncher;
  bool _isInitialized = false;

  OnNotificationMeetingLaunch? onMeetingLaunch;

  NotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    MeetingLauncher? meetingLauncher,
  })  : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
        _meetingLauncher = meetingLauncher ?? const ZoomLauncher();

  /// Initializes timezone database and notification plugin settings for iOS & Android.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize TimeZone data with device local timezone
    try {
      tz_data.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone()
          .timeout(const Duration(seconds: 2));
      final timeZoneName = tzInfo.identifier;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('[NotificationService] Timezone initialized: $timeZoneName, local: ${tz.local.name}');
      } catch (locErr) {
        debugPrint('[NotificationService] Location $timeZoneName not found in tz database: $locErr');
      }
    } catch (e) {
      debugPrint('[NotificationService] Timezone init warning: $e');
    }

    // 2. Android Initialization Settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS / Darwin Initialization Settings with Category Actions
    final darwinNotificationCategories = <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        'CLASS_REMINDER_CATEGORY',
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            AppConstants.actionJoin,
            'Tham gia ngay',
            options: {
              DarwinNotificationActionOption.foreground,
            },
          ),
          DarwinNotificationAction.plain(
            AppConstants.actionDismiss,
            'Bỏ qua',
            options: {
              DarwinNotificationActionOption.destructive,
            },
          ),
        ],
        options: {
          DarwinNotificationCategoryOption.customDismissAction,
        },
      ),
    ];

    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
      notificationCategories: darwinNotificationCategories,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackgroundHandler,
    );

    _isInitialized = true;
    debugPrint('[NotificationService] Initialized successfully.');
  }

  /// Request permissions on Android 13+ / iOS.
  Future<bool> requestPermissions() async {
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      try {
        await android.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('[NotificationService] requestExactAlarmsPermission warning: $e');
      }
      return granted ?? false;
    }

    final ios = _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  static const _alarmChannel = MethodChannel('com.autozoom/alarm');

  /// Plays alarm sound directly through speaker bypassing hardware silent switch
  Future<void> playDirectAlarm() async {
    try {
      await _alarmChannel.invokeMethod('playAlarm');
    } catch (e) {
      debugPrint('[NotificationService] playDirectAlarm error: $e');
    }
  }

  /// Stops direct alarm sound
  Future<void> stopDirectAlarm() async {
    try {
      await _alarmChannel.invokeMethod('stopAlarm');
    } catch (e) {
      debugPrint('[NotificationService] stopDirectAlarm error: $e');
    }
  }

  /// Triggers an immediate test notification with sound and banner for user verification.
  Future<void> showTestNotification() async {
    if (!_isInitialized) await initialize();
    await requestPermissions();

    // Trigger direct audio playback to bypass hardware Silent switch
    await playDirectAlarm();

    const androidDetails = AndroidNotificationDetails(
      'autozoom_alarm_channel',
      'Chuông báo nhắc giờ học Zoom',
      channelDescription: 'Phát chuông báo thức khi sắp đến giờ vào lớp học Zoom',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: 'CLASS_REMINDER_CATEGORY',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      sound: 'alarm.caf',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      999999,
      '🔔 Kiểm tra thông báo AutoZoom',
      'Thông báo và âm thanh chuông báo thức đã sẵn sàng!',
      platformDetails,
    );
  }

  /// Reconciles currently scheduled notifications with the desired upcoming class schedule.
  Future<void> reconcile({
    required List<ClassSession> upcomingClasses,
    required int reminderMinutes,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final desiredItems = NotificationReconciler.buildDesiredSchedule(
        classes: upcomingClasses,
        reminderMinutes: reminderMinutes,
      );

      final desiredIds = desiredItems.map((e) => e.id).toSet();

      // 1. Get currently scheduled notifications from OS
      final pendingList =
          await _notificationsPlugin.pendingNotificationRequests();

      // 2. Cancel stale notifications that are no longer in desired set
      for (final pending in pendingList) {
        if (!desiredIds.contains(pending.id)) {
          await _notificationsPlugin.cancel(pending.id);
          debugPrint(
              '[NotificationService] Cancelled stale notification id: ${pending.id}');
        }
      }

      // 3. Schedule all desired notifications with alarm sound
      const androidDetails = AndroidNotificationDetails(
        'autozoom_alarm_channel',
        'Chuông báo nhắc giờ học Zoom',
        channelDescription: 'Phát chuông báo thức khi sắp đến giờ vào lớp học Zoom',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('alarm'),
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        actions: [
          AndroidNotificationAction(
            AppConstants.actionJoin,
            'Tham gia ngay',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            AppConstants.actionDismiss,
            'Bỏ qua',
            cancelNotification: true,
          ),
        ],
      );

      const darwinDetails = DarwinNotificationDetails(
        categoryIdentifier: 'CLASS_REMINDER_CATEGORY',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        sound: 'alarm.caf',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      for (final item in desiredItems) {
        // Convert to TZDateTime
        final tzScheduledTime = tz.TZDateTime.from(
          item.scheduledTime,
          tz.local,
        );

        try {
          await _notificationsPlugin.zonedSchedule(
            item.id,
            item.title,
            item.body,
            tzScheduledTime,
            platformDetails,
            payload: item.payloadJson,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } on PlatformException catch (e) {
          if (e.code == 'exact_alarms_not_permitted') {
            await _notificationsPlugin.zonedSchedule(
              item.id,
              item.title,
              item.body,
              tzScheduledTime,
              platformDetails,
              payload: item.payloadJson,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          } else {
            rethrow;
          }
        }

        debugPrint(
            '[NotificationService] Scheduled notification id ${item.id} for ${item.scheduledTime} (TZ: $tzScheduledTime)');
      }
    } catch (e) {
      debugPrint('[NotificationService] Reconcile error: $e');
    }
  }

  /// Internal handler when user interacts with a notification.
  void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;

    if (actionId == AppConstants.actionDismiss) {
      debugPrint('[NotificationService] User dismissed notification.');
      return;
    }

    if (payload != null && payload.isNotEmpty) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final joinUrl = data['joinUrl'] as String?;
        final meetingId = data['meetingId'] as String?;

        if (joinUrl != null || meetingId != null) {
          final meeting = ZoomMeeting(
            joinUrl: joinUrl,
            meetingId: meetingId,
          );

          if (onMeetingLaunch != null) {
            onMeetingLaunch!(meeting);
          } else {
            _meetingLauncher.launch(meeting);
          }
        }
      } catch (e) {
        debugPrint('[NotificationService] Error parsing notification payload: $e');
      }
    }
  }
}

/// Top-level background notification tap handler required by flutter_local_notifications.
@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  final payload = response.payload;
  if (payload != null && payload.isNotEmpty) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final joinUrl = data['joinUrl'] as String?;
      final meetingId = data['meetingId'] as String?;
      if (joinUrl != null || meetingId != null) {
        const ZoomLauncher().launch(
          ZoomMeeting(joinUrl: joinUrl, meetingId: meetingId),
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Background tap error: $e');
    }
  }
}
