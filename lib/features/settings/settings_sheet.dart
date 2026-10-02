import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../services/alarm/alarm_service.dart';
import '../../services/autojoin/auto_join_service.dart';
import '../home/home_controller.dart';
import '../ptit_sync/ptit_sync_screen.dart';
import 'settings_controller.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  static const _autoJoinService = AutoJoinService();

  late final AppLifecycleListener _lifecycle;
  Map<String, bool>? _permissions;

  @override
  void initState() {
    super.initState();
    // Permissions are granted in system settings: re-check when the user comes back.
    _lifecycle = AppLifecycleListener(onResume: _refreshPermissions);
    _refreshPermissions();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    if (!Platform.isAndroid) return;
    final status = await _autoJoinService.getPermissionStatus();
    if (mounted) setState(() => _permissions = status);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final homeState = ref.watch(homeControllerProvider);
    final homeCtrl = ref.read(homeControllerProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final calendars = homeState.availableCalendars;
    final allIds = calendars.map((c) => c.id).toList();
    final permissions = _permissions;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cài đặt',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------------------------------------------------------
                    const _SectionTitle('Nhắc nhở & tự vào Zoom'),
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
                              child: Text(
                                minutes == 0
                                    ? 'Chuông reo đúng giờ học'
                                    : 'Chuông reo $minutes phút trước giờ học',
                              ),
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
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.autoJoin,
                      title: const Text(
                        'Tự động vào Zoom khi đến giờ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Android: mở Zoom đúng giờ bắt đầu kể cả khi app đã tắt. iOS: tự vào khi chuông reo lúc đang mở app.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      onChanged: (val) async {
                        await settingsCtrl.setAutoJoin(val);
                        homeCtrl.syncCalendar();
                      },
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final notifService = ref.read(
                            notificationServiceProvider,
                          );
                          await notifService.showTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Đang phát chuông báo thức thử nghiệm...',
                                ),
                                duration: const Duration(seconds: 15),
                                action: SnackBarAction(
                                  label: 'Tắt chuông',
                                  textColor: Colors.amber,
                                  onPressed: () {
                                    AlarmService().stopAlarm(
                                      AlarmService.testAlarmId,
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.notifications_active_rounded),
                        label: const Text('Thử phát chuông & thông báo'),
                        style: _outlinedStyle,
                      ),
                    ),

                    // ---------------------------------------------------------
                    if (Platform.isAndroid && permissions != null) ...[
                      const _SectionTitle('Quyền cần thiết'),
                      if (settings.autoJoin)
                        _PermissionRow(
                          label: 'Hiển thị trên ứng dụng khác',
                          hint: 'Để tự mở Zoom khi đến giờ',
                          granted: permissions['overlay'] ?? false,
                          onRequest: _autoJoinService.requestOverlayPermission,
                        ),
                      _PermissionRow(
                        label: 'Thông báo toàn màn hình',
                        hint: 'Để chuông báo hiện rõ khi khoá máy',
                        granted: permissions['fullScreen'] ?? false,
                        onRequest: _autoJoinService.requestFullScreenPermission,
                      ),
                      _PermissionRow(
                        label: 'Báo thức & lời nhắc',
                        hint:
                            'Nếu tắt, giờ nhắc có thể trễ vài phút. Bật trong Cài đặt > Ứng dụng > AutoZoom.',
                        granted: permissions['exactAlarm'] ?? true,
                      ),
                    ],

                    // ---------------------------------------------------------
                    const _SectionTitle('Lịch để quét Zoom'),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            settingsCtrl.selectAllCalendars(allIds);
                            homeCtrl.syncCalendar();
                          },
                          child: const Text('Chọn tất cả'),
                        ),
                        TextButton(
                          onPressed: () {
                            settingsCtrl.deselectAllCalendars();
                            homeCtrl.syncCalendar();
                          },
                          child: const Text('Bỏ chọn'),
                        ),
                      ],
                    ),
                    if (calendars.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'Chưa tìm thấy lịch nào trên thiết bị.',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      )
                    else
                      for (final cal in calendars)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settings.selectedCalendarIds.contains(cal.id),
                          title: Text(
                            cal.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: cal.accountName != null
                              ? Text(
                                  cal.accountName!,
                                  style: TextStyle(fontSize: 12, color: muted),
                                )
                              : null,
                          onChanged: (_) {
                            settingsCtrl.toggleCalendar(cal.id);
                            homeCtrl.syncCalendar();
                          },
                        ),

                    // ---------------------------------------------------------
                    const _SectionTitle('Đồng bộ'),
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        style: _outlinedStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _outlinedStyle = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF38BDF8)
                : const Color(0xFF0369A1),
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final String hint;
  final bool granted;
  final Future<void> Function()? onRequest;

  const _PermissionRow({
    required this.label,
    required this.hint,
    required this.granted,
    this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        granted ? Icons.check_circle_rounded : Icons.error_outline_rounded,
        color: granted ? Colors.green : Colors.orange,
        semanticLabel: granted ? 'Đã cấp' : 'Chưa cấp',
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: granted
          ? null
          : Text(hint, style: const TextStyle(fontSize: 12)),
      trailing: granted || onRequest == null
          ? null
          : TextButton(onPressed: onRequest, child: const Text('Cấp quyền')),
    );
  }
}
