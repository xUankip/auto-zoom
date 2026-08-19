import 'dart:convert';
import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/model/notification_settings.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:autozoom/features/alarm/alarm_ring_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmRingDialog Tests', () {
    testWidgets('renders alarm title, body, and action buttons',
        (tester) async {
      final payload = jsonEncode({
        'joinUrl': 'https://zoom.us/j/123456789?pwd=test',
        'meetingId': '123456789',
      });

      final alarmSettings = AlarmSettings(
        id: 101,
        dateTime: DateTime.now(),
        assetAudioPath: 'assets/alarm.wav',
        volumeSettings: const VolumeSettings.fixed(volume: 1.0),
        notificationSettings: const NotificationSettings(
          title: '🔔 Sắp đến giờ học: Tiếng Anh 101',
          body: 'Bắt đầu lúc 09:00. Nhấn để vào Zoom ngay.',
          stopButton: 'Tắt chuông',
        ),
        payload: payload,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      AlarmRingDialog.show(context, alarmSettings);
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Assert UI elements
      expect(find.text('🔔 Sắp đến giờ học: Tiếng Anh 101'), findsOneWidget);
      expect(
          find.text('Bắt đầu lúc 09:00. Nhấn để vào Zoom ngay.'), findsOneWidget);
      expect(find.text('Tham gia Zoom ngay'), findsOneWidget);
      expect(find.text('Tắt chuông báo thức'), findsOneWidget);
    });
  });
}
