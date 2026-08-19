import 'dart:convert';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';

import '../../core/models/zoom_meeting.dart';
import '../../services/alarm/alarm_service.dart';
import '../../services/meetings/zoom_launcher.dart';

/// Fullscreen alarm alert dialog displayed when a class reminder alarm triggers.
class AlarmRingDialog extends StatelessWidget {
  final AlarmSettings alarmSettings;

  const AlarmRingDialog({
    super.key,
    required this.alarmSettings,
  });

  /// Static helper to display the ring dialog on top of the current navigator.
  static Future<void> show(BuildContext context, AlarmSettings settings) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlarmRingDialog(alarmSettings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = alarmSettings.notificationSettings.title;
    final body = alarmSettings.notificationSettings.body;

    // Parse payload if available
    ZoomMeeting? meeting;
    if (alarmSettings.payload != null && alarmSettings.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(alarmSettings.payload!) as Map<String, dynamic>;
        final joinUrl = data['joinUrl'] as String?;
        final meetingId = data['meetingId'] as String?;
        if (joinUrl != null || meetingId != null) {
          meeting = ZoomMeeting(joinUrl: joinUrl, meetingId: meetingId);
        }
      } catch (e) {
        debugPrint('[AlarmRingDialog] Error parsing payload: $e');
      }
    }

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Colors.redAccent,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (meeting != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await AlarmService().stopAlarm(alarmSettings.id);
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true).pop();
                      }
                      const ZoomLauncher().launch(meeting!);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2D8CFF), // Zoom blue
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text(
                      'Tham gia Zoom ngay',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () async {
                    await AlarmService().stopAlarm(alarmSettings.id);
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tắt chuông báo thức',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
