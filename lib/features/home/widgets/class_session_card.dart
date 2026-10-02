import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/models/class_session.dart';
import '../../../core/models/zoom_meeting.dart';
import '../../../services/meetings/meeting_launcher.dart';

/// Groups a Zoom meeting ID the way Zoom shows it: 3-3-3, 3-3-4 or 3-4-4.
String formatMeetingId(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  switch (d.length) {
    case 9 || 10:
      return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
    case 11:
      return '${d.substring(0, 3)} ${d.substring(3, 7)} ${d.substring(7)}';
    default:
      return raw.trim();
  }
}

/// Android's native scheduler opens Zoom at start time; iOS only auto-joins
/// from the in-app alarm dialog, so the indicator would overpromise there.
bool get autoJoinSupported => defaultTargetPlatform == TargetPlatform.android;

class ClassSessionCard extends StatelessWidget {
  final ClassSession session;
  final Future<LaunchResult> Function(ClassSession) onJoinTap;
  final bool autoJoin;

  const ClassSessionCard({
    super.key,
    required this.session,
    required this.onJoinTap,
    this.autoJoin = false,
  });

  @override
  Widget build(BuildContext context) {
    final muted = mutedTextColor(context);
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Calendar tag & Status badge
            Row(
              children: [
                if (session.calendarName != null) ...[
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        session.calendarName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (session.isOngoing) const _OngoingBadge(),
                const Spacer(),
                Text(
                  '${session.durationMinutes} phút',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Class Title
            Text(
              session.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Time
            Row(
              children: [
                Icon(
                  Icons.access_time_filled,
                  size: 15,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF0284C7),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MeetingInfoRow(session: session, autoJoin: autoJoin, color: muted),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: JoinZoomButton(
                session: session,
                onJoinTap: onJoinTap,
                label: 'Tham gia Zoom',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color mutedTextColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF94A3B8)
    : const Color(0xFF64748B);

class _OngoingBadge extends StatelessWidget {
  const _OngoingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 10, color: Color(0xFFEF4444)),
          SizedBox(width: 4),
          Text(
            'Đang diễn ra',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

/// Meeting ID (tap / long-press to copy), "Có mật khẩu" chip and the
/// "Tự vào lúc HH:mm" indicator. Never renders the passcode itself.
class MeetingInfoRow extends StatelessWidget {
  final ClassSession session;
  final bool autoJoin;
  final Color color;

  /// Overrides the chips' accent colors (e.g. white on the hero card).
  final Color? chipColor;

  const MeetingInfoRow({
    super.key,
    required this.session,
    required this.autoJoin,
    required this.color,
    this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    final zoom = session.zoom;
    final id = zoom.meetingId;
    final hasPasscode =
        (zoom.passcode?.trim().isNotEmpty ?? false) ||
        (Uri.tryParse(zoom.joinUrl ?? '')?.queryParameters['pwd']?.isNotEmpty ??
            false);
    final style = TextStyle(fontSize: 12, color: color);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (id != null)
          Semantics(
            button: true,
            hint: 'Chạm để sao chép ID',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _copyId(context, id),
              onLongPress: () => _copyId(context, id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, size: 15, color: color),
                    const SizedBox(width: 6),
                    Text(
                      'ID: ${formatMeetingId(id)}',
                      style: style.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.copy_rounded, size: 13, color: color),
                  ],
                ),
              ),
            ),
          )
        else if (zoom.joinUrl != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 15, color: color),
              const SizedBox(width: 6),
              Text('Link Zoom', style: style),
            ],
          ),
        if (hasPasscode)
          _Chip(
            icon: Icons.lock_rounded,
            label: 'Có mật khẩu',
            color:
                chipColor ??
                (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF15803D)),
          ),
        if (autoJoin && autoJoinSupported && session.isUpcoming)
          _Chip(
            icon: Icons.bolt_rounded,
            label:
                'Tự vào lúc ${DateFormat('HH:mm').format(session.startTime)}',
            color:
                chipColor ??
                (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF0369A1)),
          ),
      ],
    );
  }

  static void _copyId(BuildContext context, String id) {
    Clipboard.setData(ClipboardData(text: id.replaceAll(RegExp(r'\D'), '')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép Meeting ID'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Join button with a loading state while Zoom is opening and a SnackBar
/// (with a copy-ID fallback) when the launch fails.
class JoinZoomButton extends StatefulWidget {
  final ClassSession session;
  final Future<LaunchResult> Function(ClassSession) onJoinTap;
  final String label;
  final ButtonStyle? style;

  const JoinZoomButton({
    super.key,
    required this.session,
    required this.onJoinTap,
    required this.label,
    this.style,
  });

  @override
  State<JoinZoomButton> createState() => _JoinZoomButtonState();
}

class _JoinZoomButtonState extends State<JoinZoomButton> {
  bool _busy = false;

  Future<void> _join() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    LaunchResult res;
    try {
      res = await widget.onJoinTap(widget.session);
    } catch (e) {
      res = LaunchResult.failed('Không thể mở Zoom: $e');
    }
    if (mounted) setState(() => _busy = false);
    if (res.isSuccess) return;
    final id = widget.session.zoom.meetingId;
    messenger.showSnackBar(
      SnackBar(
        content: Text(res.errorMessage ?? 'Không thể mở Zoom.'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 6),
        action: id == null
            ? null
            : SnackBarAction(
                label: 'Sao chép ID',
                textColor: Colors.white,
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: id.replaceAll(RegExp(r'\D'), '')),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: (widget.style ?? const ButtonStyle()).merge(
        ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
      onPressed: _busy || !_canLaunch(widget.session.zoom) ? null : _join,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.video_call_rounded, size: 20),
      label: Text(
        _busy ? 'Đang mở Zoom…' : widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static bool _canLaunch(ZoomMeeting z) =>
      z.computedUrl != null || z.deepLinkUrl != null;
}
