import 'package:flutter/material.dart';

import '../../ptit_sync/ptit_sync_screen.dart';

class EmptyScheduleView extends StatelessWidget {
  final VoidCallback onRefresh;
  final int filterDays;

  const EmptyScheduleView({
    super.key,
    required this.onRefresh,
    this.filterDays = 7,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_available_rounded, size: 48, color: muted),
          ),
          const SizedBox(height: 16),
          Text(
            'Không còn lớp Zoom nào trong $filterDays ngày tới',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sự kiện trong lịch có link Zoom hoặc Meeting ID sẽ tự hiện ở đây. '
            'Hãy kiểm tra lịch đã chọn trong Cài đặt, hoặc đồng bộ thời khoá biểu PTIT vào lịch.',
            style: TextStyle(fontSize: 13, color: muted, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PtitSyncScreen()),
            ),
            icon: const Icon(Icons.school_rounded, size: 18),
            label: const Text('Đồng bộ TKB PTIT'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Làm mới lịch'),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          const SizedBox(height: 4),
          Text(
            'Mẹo: kéo màn hình xuống để làm mới',
            style: TextStyle(fontSize: 12, color: muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
