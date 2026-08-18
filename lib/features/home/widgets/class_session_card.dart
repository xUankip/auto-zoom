import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/class_session.dart';
import '../../../services/meetings/meeting_launcher.dart';

class ClassSessionCard extends StatelessWidget {
  final ClassSession session;
  final Future<LaunchResult> Function(ClassSession) onJoinTap;

  const ClassSessionCard({
    super.key,
    required this.session,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('HH:mm');

    final isToday = DateTime.now().year == session.startTime.year &&
        DateTime.now().month == session.startTime.month &&
        DateTime.now().day == session.startTime.day;

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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      session.calendarName!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (session.isOngoing)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record,
                            size: 10, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'Đang diễn ra',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text(
                  '${session.durationMinutes} phút',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Class Title
            Text(
              session.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Time & Date
            Row(
              children: [
                Icon(
                  Icons.access_time_filled,
                  size: 15,
                  color: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF0284C7),
                ),
                const SizedBox(width: 6),
                Text(
                  '${timeFormat.format(session.startTime)} - ${timeFormat.format(session.endTime)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF334155),
                  ),
                ),
                if (!isToday) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${DateFormat('dd/MM').format(session.startTime)})',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),

            // Zoom Details Summary
            if (session.zoom.meetingId != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.videocam,
                    size: 15,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ID: ${session.zoom.meetingId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (session.zoom.passcode != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      'Mật khẩu: ••••••',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Action Button: Tham gia Zoom
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final scaffold = ScaffoldMessenger.of(context);
                  final res = await onJoinTap(session);
                  if (res.status == LaunchStatus.failed) {
                    scaffold.showSnackBar(
                      SnackBar(
                        content: Text(res.errorMessage ?? 'Không thể mở Zoom.'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.video_call_rounded, size: 20),
                label: const Text('Tham gia Zoom'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
