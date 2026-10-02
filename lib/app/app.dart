import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/alarm/alarm_ring_screen.dart';
import '../features/home/home_controller.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_controller.dart';
import '../services/alarm/alarm_service.dart';
import 'app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AutoZoomApp extends ConsumerStatefulWidget {
  const AutoZoomApp({super.key});

  @override
  ConsumerState<AutoZoomApp> createState() => _AutoZoomAppState();
}

class _AutoZoomAppState extends ConsumerState<AutoZoomApp> {
  late final AppLifecycleListener _lifecycleListener;

  /// Alarm ids whose dialog is currently on screen (the ringing stream re-emits all ringing alarms).
  final Set<int> _shownAlarmIds = {};

  @override
  void initState() {
    super.initState();
    // Register alarm ring listener
    AlarmService().onAlarmRing = _showAlarmDialog;

    // Cold start: an alarm may have started ringing before the listener/navigator existed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final alarm in await AlarmService().getRingingAlarms()) {
        if (!mounted) return;
        _showAlarmDialog(alarm);
      }
    });

    // Reconcile notifications whenever the app returns to foreground
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        debugPrint('[AppLifecycle] Resumed into foreground -> triggering calendar sync.');
        ref.read(homeControllerProvider.notifier).syncCalendar();
      },
    );
  }

  void _showAlarmDialog(AlarmSettings alarmSettings) {
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null || !_shownAlarmIds.add(alarmSettings.id)) return;
    AlarmRingDialog.show(
      navContext,
      alarmSettings,
      autoJoin: ref.read(settingsControllerProvider).autoJoin,
    ).whenComplete(() => _shownAlarmIds.remove(alarmSettings.id));
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'AutoZoom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
