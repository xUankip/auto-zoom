import 'dart:async';
import 'dart:convert';
import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';

import '../../core/models/zoom_meeting.dart';
import '../../services/alarm/alarm_service.dart';
import '../../services/autojoin/auto_join_service.dart';
import '../../services/meetings/zoom_launcher.dart';
import '../home/widgets/class_session_card.dart' show formatMeetingId;

/// Fullscreen alarm alert dialog displayed when a class reminder alarm triggers.
class AlarmRingDialog extends StatefulWidget {
  final AlarmSettings alarmSettings;

  /// When true and the class starts within 5 minutes, joins Zoom after a short countdown.
  final bool autoJoin;

  const AlarmRingDialog({
    super.key,
    required this.alarmSettings,
    this.autoJoin = false,
  });

  /// Static helper to display the ring dialog on top of the current navigator.
  static Future<void> show(
    BuildContext context,
    AlarmSettings settings, {
    bool autoJoin = false,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          AlarmRingDialog(alarmSettings: settings, autoJoin: autoJoin),
    );
  }

  @override
  State<AlarmRingDialog> createState() => _AlarmRingDialogState();
}

class _AlarmRingDialogState extends State<AlarmRingDialog> {
  ZoomMeeting? _meeting;
  Timer? _countdown;
  int _secondsLeft = 15;

  @override
  void initState() {
    super.initState();
    final payload = widget.alarmSettings.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['joinUrl'] != null || data['meetingId'] != null) {
        _meeting = ZoomMeeting.fromJson(data);
      }
      final startTime = DateTime.tryParse(data['startTime'] as String? ?? '');
      if (_meeting != null &&
          widget.autoJoin &&
          startTime != null &&
          startTime.difference(DateTime.now()) <= const Duration(minutes: 5)) {
        _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_secondsLeft <= 1) {
            _join();
          } else {
            setState(() => _secondsLeft--);
          }
        });
      }
    } catch (e) {
      debugPrint('[AlarmRingDialog] Error parsing payload: $e');
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _join() async {
    _countdown?.cancel();
    _countdown = null;
    final meeting = _meeting;
    if (meeting == null) return;
    _meeting = null; // guard against a double tap / timer racing the button
    await AlarmService().stopAlarm(widget.alarmSettings.id);
    // Joining now: don't let the native scheduler re-open Zoom at start time.
    const AutoJoinService().cancel(widget.alarmSettings.id);
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    const ZoomLauncher().launch(meeting);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alarmSettings = widget.alarmSettings;
    final title = alarmSettings.notificationSettings.title;
    final body = alarmSettings.notificationSettings.body;
    final meeting = _meeting;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          // Scrolls instead of overflowing with large system font sizes.
          child: SingleChildScrollView(
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
                if (meeting?.meetingId != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'ID: ${formatMeetingId(meeting!.meetingId!)}'
                    '${(meeting.passcode?.isNotEmpty ?? false) ? ' · Có mật khẩu' : ''}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                if (meeting != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _join,
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
                if (_countdown != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _secondsLeft / 15,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tự vào Zoom sau ${_secondsLeft}s',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => setState(() {
                      _countdown?.cancel();
                      _countdown = null;
                    }),
                    child: const Text('Huỷ tự vào'),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      _countdown?.cancel();
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
      ),
    );
  }
}
