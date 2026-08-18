import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/zoom_meeting.dart';
import 'meeting_launcher.dart';

/// Concrete Zoom meeting launcher.
/// Priority:
/// 1. If [joinUrl] is present (from calendar event), launch it directly via Universal/App Link.
/// 2. If only [meetingId] (+ optional [passcode]) is present, try [deepLinkUrl] then fallback to constructed HTTPS URL.
/// ponytail: Direct launching preserves custom/region-specific vanity URLs without unnecessary transformation.
class ZoomLauncher implements MeetingLauncher {
  const ZoomLauncher();

  @override
  Future<LaunchResult> launch(ZoomMeeting meeting) async {
    // Priority 1: Direct joinUrl from event
    if (meeting.joinUrl != null && meeting.joinUrl!.trim().isNotEmpty) {
      final rawUrl = meeting.joinUrl!.trim();
      try {
        final uri = Uri.parse(rawUrl);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          debugPrint('[ZoomLauncher] Launched direct joinUrl: $rawUrl');
          return LaunchResult.appLaunched(rawUrl);
        }
      } catch (e) {
        debugPrint('[ZoomLauncher] Failed to launch joinUrl: $e');
        return LaunchResult.failed('Không thể mở liên kết Zoom: $e');
      }
    }

    // Priority 2: Constructed from Meeting ID (+ optional Passcode)
    final deepLink = meeting.deepLinkUrl;
    final httpsUrl = meeting.computedUrl;

    if (deepLink == null && httpsUrl == null) {
      return LaunchResult.failed('Không tìm thấy đường dẫn hoặc mã phòng Zoom.');
    }

    // Try deep link scheme first
    if (deepLink != null) {
      try {
        final deepUri = Uri.parse(deepLink);
        if (await canLaunchUrl(deepUri)) {
          final launched = await launchUrl(
            deepUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            debugPrint('[ZoomLauncher] Launched Zoom scheme: $deepLink');
            return LaunchResult.appLaunched(deepLink);
          }
        }
      } catch (e) {
        debugPrint('[ZoomLauncher] Deep link launch failed, trying HTTPS: $e');
      }
    }

    // Fallback to HTTPS
    if (httpsUrl != null) {
      try {
        final httpsUri = Uri.parse(httpsUrl);
        final launched = await launchUrl(
          httpsUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          debugPrint('[ZoomLauncher] Launched HTTPS fallback: $httpsUrl');
          return LaunchResult.webFallback(httpsUrl);
        }
      } catch (e) {
        debugPrint('[ZoomLauncher] HTTPS fallback failed: $e');
        return LaunchResult.failed('Không thể mở liên kết Zoom: $e');
      }
    }

    return LaunchResult.failed('Không thể mở ứng dụng Zoom hoặc trình duyệt.');
  }
}
