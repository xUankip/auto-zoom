import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/settings/settings_controller.dart';
import 'services/alarm/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences & Alarm audio engine
  final sharedPreferences = await SharedPreferences.getInstance();
  await AlarmService().initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const AutoZoomApp(),
    ),
  );
}


