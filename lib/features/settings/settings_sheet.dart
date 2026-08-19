import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../home/home_controller.dart';
import '../ptit_sync/ptit_sync_screen.dart';
import 'settings_controller.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final homeState = ref.watch(homeControllerProvider);
    final homeCtrl = ref.read(homeControllerProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final calendars = homeState.availableCalendars;
    final allIds = calendars.map((c) => c.id).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cài đặt Lịch & Nhắc nhở',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    splashRadius: 20,
                  ),
                ],
              ),
              const Divider(height: 24),

              // Reminder Time Offset
              const Text(
                'Thời gian nhắc nhở',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: settings.reminderMinutes,
                    isExpanded: true,
                    items: AppConstants.reminderOptions.map((minutes) {
                      return DropdownMenuItem<int>(
                        value: minutes,
                        child: Text('$minutes phút trước giờ học'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        settingsCtrl.setReminderMinutes(val);
                        homeCtrl.syncCalendar();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Calendar Selection Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn Lịch để quét Zoom',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          settingsCtrl.selectAllCalendars(allIds);
                          homeCtrl.syncCalendar();
                        },
                        child: const Text('Chọn tất cả',
                            style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () {
                          settingsCtrl.deselectAllCalendars();
                          homeCtrl.syncCalendar();
                        },
                        child: const Text('Bỏ chọn',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (calendars.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Chưa tìm thấy lịch nào trên thiết bị.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: calendars.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cal = calendars[index];
                    final isSelected =
                        settings.selectedCalendarIds.contains(cal.id);

                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isSelected,
                      title: Text(
                        cal.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: cal.accountName != null
                          ? Text(
                              cal.accountName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            )
                          : null,
                      onChanged: (_) {
                        settingsCtrl.toggleCalendar(cal.id);
                        homeCtrl.syncCalendar();
                      },
                    );
                  },
                ),

              const SizedBox(height: 20),

              // Test Notification Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final notifService = ref.read(notificationServiceProvider);
                    await notifService.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Đang phát chuông báo thức thử nghiệm...'),
                          duration: const Duration(seconds: 15),
                          action: SnackBarAction(
                            label: 'Tắt chuông',
                            textColor: Colors.amber,
                            onPressed: () {
                              notifService.stopDirectAlarm();
                            },
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: const Text('Thử phát chuông & thông báo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Manual Sync Now Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    homeCtrl.syncCalendar();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Đồng bộ ngay'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),

              // PTIT Auto-sync TKB
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PtitSyncScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.school_rounded),
                  label: const Text('Đồng bộ TKB từ PTIT'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
