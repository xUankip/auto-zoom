import '../../core/models/zoom_meeting.dart';

enum LaunchStatus {
  appLaunched,
  webFallback,
  failed,
}

class LaunchResult {
  final LaunchStatus status;
  final String? launchedUrl;
  final String? errorMessage;

  const LaunchResult({
    required this.status,
    this.launchedUrl,
    this.errorMessage,
  });

  bool get isSuccess =>
      status == LaunchStatus.appLaunched || status == LaunchStatus.webFallback;

  factory LaunchResult.appLaunched(String url) => LaunchResult(
        status: LaunchStatus.appLaunched,
        launchedUrl: url,
      );

  factory LaunchResult.webFallback(String url) => LaunchResult(
        status: LaunchStatus.webFallback,
        launchedUrl: url,
      );

  factory LaunchResult.failed(String msg) => LaunchResult(
        status: LaunchStatus.failed,
        errorMessage: msg,
      );
}

/// Abstract contract for meeting launchers (Zoom, Google Meet, Teams, etc.).
abstract class MeetingLauncher {
  Future<LaunchResult> launch(ZoomMeeting meeting);
}
