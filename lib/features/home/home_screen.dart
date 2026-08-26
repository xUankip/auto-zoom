import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../settings/settings_sheet.dart';
import 'home_controller.dart';
import 'widgets/class_session_card.dart';
import 'widgets/empty_schedule_view.dart';
import 'widgets/permission_request_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeControllerProvider);
    final homeCtrl = ref.read(homeControllerProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
            onPressed:
                homeState.isLoading ? null : () => homeCtrl.syncCalendar(),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SettingsSheet(),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => homeCtrl.syncCalendar(),
        child: _buildBody(context, ref, homeState, homeCtrl),
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    HomeState state,
    HomeController ctrl,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: AppConstants.scheduleFilterDaysOptions.map((days) {
          final isSelected = state.filterDays == days;
          return Expanded(
            child: GestureDetector(
              key: ValueKey('filter_days_$days'),
              onTap: () => ctrl.setFilterDays(days),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF0284C7) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.08,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$days ngày',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final todayClasses = state.todayClasses;
    final upcomingClasses = state.upcomingDaysClasses;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Filter selector bar
        _buildFilterBar(context, state, ctrl),

        if (state.errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              state.errorMessage!,
              style: TextStyle(fontSize: 13, color: Colors.red.shade800),
            ),
          ),

        if (state.classes.isEmpty)
          EmptyScheduleView(
            filterDays: state.filterDays,
            onRefresh: () => ctrl.syncCalendar(),
          )
        else ...[
          // Section: Today
          if (todayClasses.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'HÔM NAY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
            ...todayClasses.map(
              (session) => ClassSessionCard(
                session: session,
                onJoinTap: ctrl.launchMeeting,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Section: Upcoming
          if (upcomingClasses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
              child: Text(
                '${state.filterDays} NGÀY TỚI',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            ...upcomingClasses.map(
              (session) => ClassSessionCard(
                session: session,
                onJoinTap: ctrl.launchMeeting,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
