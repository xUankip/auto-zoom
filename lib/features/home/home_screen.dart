import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/class_session.dart';
import '../../services/autojoin/auto_join_service.dart';
import '../../services/meetings/meeting_launcher.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_sheet.dart';
import 'home_controller.dart';
import 'widgets/class_session_card.dart';
import 'widgets/empty_schedule_view.dart';
import 'widgets/permission_request_card.dart';

/// "Hôm nay" / "Ngày mai" / "Thứ 5, 08/10" / "Chủ nhật, 11/10".
String dayLabel(DateTime day, DateTime now) {
  if (DateUtils.isSameDay(day, now)) return 'Hôm nay';
  if (DateUtils.isSameDay(day, DateTime(now.year, now.month, now.day + 1))) {
    return 'Ngày mai';
  }
  final weekday = day.weekday == DateTime.sunday
      ? 'Chủ nhật'
      : 'Thứ ${day.weekday + 1}';
  return '$weekday, ${DateFormat('dd/MM').format(day)}';
}

/// Live countdown for the next class, e.g. "Bắt đầu sau 12 phút" / "Đang diễn ra · còn 1 giờ".
String countdownLabel(DateTime start, DateTime end, DateTime now) {
  String dur(int m) => m < 60
      ? '$m phút'
      : m % 60 == 0
      ? '${m ~/ 60} giờ'
      : '${m ~/ 60} giờ ${m % 60} phút';

  if (!now.isBefore(start)) {
    final left = (end.difference(now).inSeconds / 60).ceil();
    return 'Đang diễn ra · còn ${dur(left < 1 ? 1 : left)}';
  }
  final mins = (start.difference(now).inSeconds / 60).ceil();
  if (mins <= 1) return 'Sắp bắt đầu';
  if (mins < 24 * 60) return 'Bắt đầu sau ${dur(mins)}';
  return 'Bắt đầu sau ${mins ~/ (24 * 60)} ngày';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _autoJoinService = AutoJoinService();

  /// Re-renders countdowns and moves finished classes out of the list.
  late final Timer _ticker;
  late final AppLifecycleListener _lifecycle;
  Map<String, bool> _permissions = const {};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // The user fixes permissions in system settings, then comes back.
    _lifecycle = AppLifecycleListener(onResume: _refreshPermissions);
    _refreshPermissions();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    final status = await _autoJoinService.getPermissionStatus();
    if (mounted) setState(() => _permissions = status);
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
    _refreshPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeControllerProvider);
    final homeCtrl = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AutoZoom'),
            Text(
              homeState.lastSyncedAt != null
                  ? 'Đồng bộ: ${DateFormat('HH:mm').format(homeState.lastSyncedAt!)}'
                  : 'Lịch học thông minh',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: mutedTextColor(context),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ lịch',
            icon: homeState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: homeState.isLoading
                ? null
                : () => homeCtrl.syncCalendar(),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => homeCtrl.syncCalendar(),
        child: _buildBody(context, homeState, homeCtrl),
      ),
    );
  }

  /// Missing Android permissions that make reminders / auto-join fail silently.
  List<({String label, Future<void> Function() fix})> _missingPermissions(
    bool autoJoin,
  ) {
    return [
      if (autoJoin && _permissions['overlay'] == false)
        (
          label: '"Hiển thị trên ứng dụng khác" — để tự mở Zoom khi đến giờ',
          fix: _autoJoinService.requestOverlayPermission,
        ),
      if (_permissions['fullScreen'] == false)
        (
          label:
              '"Thông báo toàn màn hình" — để chuông báo hiện rõ khi khoá máy',
          fix: _autoJoinService.requestFullScreenPermission,
        ),
    ];
  }

  Widget _buildBody(
    BuildContext context,
    HomeState state,
    HomeController ctrl,
  ) {
    if (!state.hasCalendarPermission) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PermissionRequestCard(
            onRequestPermission: () => ctrl.requestPermissions(),
          ),
        ],
      );
    }

    if (state.isLoading && state.classes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final autoJoin = ref.watch(settingsControllerProvider).autoJoin;
    final now = DateTime.now();
    // Finished classes are no longer actionable; the first remaining one is the hero.
    final visible = state.classes.where((c) => c.endTime.isAfter(now)).toList();
    final next = visible.isEmpty ? null : visible.first;
    final rest = visible.skip(1).toList();
    final missing = _missingPermissions(autoJoin);

    final listItems = <Widget>[];
    DateTime? currentDay;
    for (final session in rest) {
      if (currentDay == null ||
          !DateUtils.isSameDay(currentDay, session.startTime)) {
        currentDay = session.startTime;
        listItems.add(_DayHeader(dayLabel(session.startTime, now)));
      }
      listItems.add(
        ClassSessionCard(
          session: session,
          onJoinTap: ctrl.launchMeeting,
          autoJoin: autoJoin,
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (missing.isNotEmpty) _PermissionBanner(missing: missing),
        if (state.errorMessage != null)
          _ErrorBox(
            message: state.errorMessage!,
            onRetry: () => ctrl.syncCalendar(),
          ),
        if (next != null)
          _NextClassHero(
            session: next,
            now: now,
            autoJoin: autoJoin,
            onJoinTap: ctrl.launchMeeting,
          ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: [
              for (final days in AppConstants.scheduleFilterDaysOptions)
                ButtonSegment(value: days, label: Text('$days ngày')),
            ],
            selected: {state.filterDays},
            showSelectedIcon: false,
            onSelectionChanged: (s) => ctrl.setFilterDays(s.first),
          ),
        ),
        const SizedBox(height: 8),
        if (next == null)
          EmptyScheduleView(
            filterDays: state.filterDays,
            onRefresh: () => ctrl.syncCalendar(),
          )
        else if (rest.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Không còn lớp Zoom nào khác trong ${state.filterDays} ngày tới.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: mutedTextColor(context)),
            ),
          )
        else
          ...listItems,
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF38BDF8) : AppTheme.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _NextClassHero extends StatelessWidget {
  final ClassSession session;
  final DateTime now;
  final bool autoJoin;
  final Future<LaunchResult> Function(ClassSession) onJoinTap;

  const _NextClassHero({
    required this.session,
    required this.now,
    required this.autoJoin,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    final ongoing = !now.isBefore(session.startTime);
    final time = DateFormat('HH:mm');
    final soft = Colors.white.withValues(alpha: 0.9);
    final accent = ongoing ? const Color(0xFFB91C1C) : AppTheme.primaryDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ongoing
              ? const [Color(0xFFB91C1C), Color(0xFF7F1D1D)]
              : const [AppTheme.primaryDark, Color(0xFF0C4A6E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ongoing ? 'ĐANG DIỄN RA' : 'LỚP TIẾP THEO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: soft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            session.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${dayLabel(session.startTime, now)} · '
            '${time.format(session.startTime)} - ${time.format(session.endTime)}',
            style: TextStyle(fontSize: 14, color: soft),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              countdownLabel(session.startTime, session.endTime, now),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          MeetingInfoRow(
            session: session,
            autoJoin: autoJoin,
            color: soft,
            chipColor: Colors.white,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: JoinZoomButton(
              session: session,
              onJoinTap: onJoinTap,
              label: 'Vào Zoom ngay',
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: accent,
                // Keeps "Đang mở Zoom…" readable on the colored card.
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.85),
                disabledForegroundColor: accent,
                minimumSize: const Size(0, 54),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final List<({String label, Future<void> Function() fix})> missing;

  const _PermissionBanner({required this.missing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF422006) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF854D0E) : const Color(0xFFFCD34D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: fg, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thiếu quyền — bạn có thể lỡ lớp',
                  style: TextStyle(fontWeight: FontWeight.bold, color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final m in missing)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text(
                '• Cho phép ${m.label}',
                style: TextStyle(fontSize: 13, color: fg, height: 1.35),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: missing.first.fix,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Cấp quyền ngay'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: scheme.onErrorContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Thử lại'),
            ),
          ),
        ],
      ),
    );
  }
}
