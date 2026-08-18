import 'package:autozoom/core/parser/zoom_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZoomParser Test Suite', () {
    test('parses standard Zoom URL with password', () {
      final result = ZoomParser.parse(
        description: 'Join Zoom Class: https://zoom.us/j/123456789?pwd=abcdef',
      );
      expect(result, isNotNull);
      expect(result!.meetingId, '123456789');
      expect(result.passcode, 'abcdef');
      expect(result.joinUrl, 'https://zoom.us/j/123456789?pwd=abcdef');
      expect(result.computedUrl, 'https://zoom.us/j/123456789?pwd=abcdef');
    });

    test('parses subdomain Zoom URL with additional query params', () {
      final result = ZoomParser.parse(
        location:
            'https://us02web.zoom.us/j/98765432101?pwd=pass123&status=success',
      );
      expect(result, isNotNull);
      expect(result!.meetingId, '98765432101');
      expect(result.passcode, 'pass123');
    });

    test('parses Zoom URL without password', () {
      final result = ZoomParser.parse(
        description: 'Meeting link: https://zoom.us/j/123456789',
      );
      expect(result, isNotNull);
      expect(result!.meetingId, '123456789');
      expect(result.passcode, isNull);
      expect(result.computedUrl, 'https://zoom.us/j/123456789');
    });

    test('parses English Meeting ID and Passcode with spaces', () {
      final result = ZoomParser.parse(
        description: '''
Lập trình Mobile
Zoom Meeting
Meeting ID: 123 456 789
Passcode: secret123
''',
      );
      expect(result, isNotNull);
      expect(result!.meetingId, '123456789');
      expect(result.passcode, 'secret123');
      expect(
        result.computedUrl,
        'https://zoom.us/j/123456789?pwd=secret123',
      );
    });

    test('parses Vietnamese format: ID phòng and Mật khẩu', () {
      final result = ZoomParser.parse(
        description: '''
Buổi học React Native
ID phòng: 987 654 321 01
Mật khẩu: abc@123
''',
      );
      expect(result, isNotNull);
      expect(result!.meetingId, '98765432101');
      expect(result.passcode, 'abc@123');
    });

    test('parses hyphenated ID and Password', () {
      final result = ZoomParser.parse(
        description: '''
ID: 123-456-789
Password: mypassword
''',
      );
      expect(result, isNotNull);
      expect(result!.meetingId, '123456789');
      expect(result.passcode, 'mypassword');
    });

    test('parses Zoom ID from title and passcode from description', () {
      final result = ZoomParser.parse(
        title: 'Class Room (ID: 123456789)',
        description: 'Mã bảo mật: 654321',
      );
      expect(result, isNotNull);
      expect(result!.meetingId, '123456789');
      expect(result.passcode, '654321');
    });

    test('returns null for unrelated text and numbers', () {
      expect(ZoomParser.parse(description: 'Ăn trưa tại quán 123 Nguyễn Trãi'), isNull);
      expect(ZoomParser.parse(description: 'Gọi số điện thoại: 0901234567'), isNull);
      expect(ZoomParser.parse(description: 'ID: 1234'), isNull); // Too short
      expect(ZoomParser.parse(description: ''), isNull);
      expect(ZoomParser.parse(), isNull);
    });
  });
}
