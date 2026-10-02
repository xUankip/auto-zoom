import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/zoom_meeting.dart';
import 'meeting_launcher.dart';

/// Concrete Zoom meeting launcher.
/// Priority:
/// 1. Native [deepLinkUrl] (`zoomus://zoom.us/join?...`) — opens the Zoom app directly,
///    skipping the browser "Launch meeting" page.
/// 2. HTTPS [computedUrl]: raw [joinUrl] from the event (Universal/App Link → appLaunched),
///    or one constructed from [meetingId] (+ optional [passcode]) → webFallback.
/// 3. Otherwise failed.
/// ponytail: Raw joinUrl is launched as-is, preserving custom/region-specific vanity URLs.
class ZoomLauncher implements MeetingLauncher {
  const ZoomLauncher();

  @override
  Future<LaunchResult> launch(ZoomMeeting meeting) async {
    final deepLink = meeting.deepLinkUrl;
    final httpsUrl = meeting.computedUrl;

    if (deepLink == null && httpsUrl == null) {
      return LaunchResult.failed('Không tìm thấy đường dẫn hoặc mã phòng Zoom.');
    }

    // Priority 1: Native Zoom scheme
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

    // Priority 2: HTTPS (raw joinUrl from event, or constructed from Meeting ID)
    if (httpsUrl != null) {
      final isRawJoinUrl =
          meeting.joinUrl != null && meeting.joinUrl!.trim().isNotEmpty;
      try {
        final launched = await launchUrl(
          Uri.parse(httpsUrl),
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          debugPrint('[ZoomLauncher] Launched HTTPS URL: $httpsUrl');
          return isRawJoinUrl
              ? LaunchResult.appLaunched(httpsUrl)
              : LaunchResult.webFallback(httpsUrl);
        }
      } catch (e) {
        debugPrint('[ZoomLauncher] HTTPS launch failed: $e');
        return LaunchResult.failed('Không thể mở liên kết Zoom: $e');
      }
    }

    return LaunchResult.failed('Không thể mở ứng dụng Zoom hoặc trình duyệt.');
  }
}
