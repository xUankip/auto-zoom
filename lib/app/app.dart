import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/alarm/alarm_ring_screen.dart';
import '../features/home/home_controller.dart';
import '../features/home/home_screen.dart';
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

  @override
  void initState() {
    super.initState();
    // Register alarm ring listener
    AlarmService().onAlarmRing = (alarmSettings) {
      final navContext = appNavigatorKey.currentContext;
      if (navContext != null) {
        AlarmRingDialog.show(navContext, alarmSettings);
      }
    };

    // Reconcile notifications whenever the app returns to foreground
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        debugPrint('[AppLifecycle] Resumed into foreground -> triggering calendar sync.');
        ref.read(homeControllerProvider.notifier).syncCalendar();
      },
    );
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

