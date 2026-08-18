import 'package:flutter/material.dart';

class PermissionRequestCard extends StatelessWidget {
  final VoidCallback onRequestPermission;

  const PermissionRequestCard({
    super.key,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 48,
              color: Color(0xFF0284C7),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cần quyền truy cập Lịch',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'AutoZoom cần quyền truy cập lịch để tìm các buổi học và tự động nhắc bạn trước giờ học.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRequestPermission,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Cho phép truy cập Calendar'),
            ),
          ],
        ),
      ),
    );
  }
}
