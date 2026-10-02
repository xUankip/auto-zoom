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
import '../alarm/alarm_service.dart';
import '../autojoin/auto_join_service.dart';
import '../meetings/meeting_launcher.dart';
import '../meetings/zoom_launcher.dart';
import 'notification_reconciler.dart';

/// Manages local notification scheduling, interactive actions, and Zoom meeting auto-launching.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final MeetingLauncher _meetingLauncher;
  final AlarmService _alarmService;
  bool _isInitialized = false;

  /// Static: the plugin is a singleton, so a new service instance would replay the same launch.
  static bool _launchResponseHandled = false;

  /// Silent on Android: the `alarm` package already rings, even when the app is killed.
  /// iOS keeps the sound because the alarm package can't ring once the app is killed.
  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'autozoom_join_channel',
      'Nhắc vào lớp Zoom',
      channelDescription: 'Thông báo nhắc vào lớp học Zoom (chuông báo thức phát riêng)',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
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
    ),
    iOS: DarwinNotificationDetails(
      categoryIdentifier: 'CLASS_REMINDER_CATEGORY',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      sound: 'alarm.caf',
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  NotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    MeetingLauncher? meetingLauncher,
    AlarmService? alarmService,
  })  : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
        _meetingLauncher = meetingLauncher ?? const ZoomLauncher(),
        _alarmService = alarmService ?? AlarmService();

  /// Initializes timezone database and notification plugin settings for iOS & Android.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 0. Initialize Alarm audio engine
    await _alarmService.initialize();

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

    // Cold start: the app was launched by tapping a notification / its action.
    final launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (!_launchResponseHandled &&
        (launchDetails?.didNotificationLaunchApp ?? false) &&
        launchResponse != null) {
      _launchResponseHandled = true;
      _handleNotificationResponse(launchResponse);
    }
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

  /// Triggers an immediate test notification with sound and banner for user verification.
  Future<void> showTestNotification() async {
    if (!_isInitialized) await initialize();
    await requestPermissions();

    // Trigger test alarm bypassing hardware Silent switch
    await _alarmService.triggerTestAlarm();

    await _notificationsPlugin.show(
      999999,
      '🔔 Kiểm tra thông báo AutoZoom',
      'Thông báo và âm thanh chuông báo thức đã sẵn sàng!',
      _notificationDetails,
    );
  }

  /// Reconciles currently scheduled notifications with the desired upcoming class schedule.
  Future<void> reconcile({
    required List<ClassSession> upcomingClasses,
    required int reminderMinutes,
    required bool autoJoin,
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

      // 3. Schedule all desired notifications
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
            _notificationDetails,
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
              _notificationDetails,
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

      // 4. Synchronize hardware-silent-bypassing background audio alarms
      await _alarmService.reconcileAlarms(desiredItems: desiredItems);
    } catch (e) {
      debugPrint('[NotificationService] Reconcile error: $e');
    }

    // 5. Native Android auto-join at class start (no-op elsewhere)
    await const AutoJoinService().sync(autoJoin ? upcomingClasses : const []);
  }

  /// Internal handler when user interacts with a notification.
  void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    final notificationId = response.id;

    // Stop ringing alarm if user interacts with notification
    if (notificationId != null) {
      _alarmService.stopAlarm(notificationId);
    } else {
      _alarmService.stopAll();
    }

    if (actionId == AppConstants.actionDismiss) {
      debugPrint('[NotificationService] User dismissed notification.');
      if (notificationId != null) {
        const AutoJoinService().cancel(notificationId);
      }
      return;
    }

    if (payload != null && payload.isNotEmpty) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        if (data['joinUrl'] != null || data['meetingId'] != null) {
          // Joining now: don't let the native scheduler re-open Zoom at start time.
          if (notificationId != null) {
            const AutoJoinService().cancel(notificationId);
          }
          _meetingLauncher.launch(ZoomMeeting.fromJson(data));
        }
      } catch (e) {
        debugPrint('[NotificationService] Error parsing notification payload: $e');
      }
    }
  }
}

/// Top-level background notification response handler required by flutter_local_notifications.
/// Runs in a background isolate where launching another app doesn't work, so it only
/// stops the alarm (taps that open the app go through [NotificationService] instead).
@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  final id = response.id;
  if (id == null) {
    AlarmService().stopAll();
    return;
  }
  AlarmService().stopAlarm(id);
  if (response.actionId == AppConstants.actionDismiss) {
    const AutoJoinService().cancel(id);
  }
}
