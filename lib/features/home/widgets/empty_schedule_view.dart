import 'package:flutter/material.dart';

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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 48,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không tìm thấy lịch học Zoom',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Các sự kiện có Zoom URL hoặc Meeting ID trong $filterDays ngày tới sẽ tự động xuất hiện tại đây.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Làm mới lịch'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
