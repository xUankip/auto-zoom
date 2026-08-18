/// Represents parsed Zoom meeting credentials and connection details.
class ZoomMeeting {
  final String? joinUrl;
  final String? meetingId;
  final String? passcode;

  const ZoomMeeting({
    this.joinUrl,
    this.meetingId,
    this.passcode,
  });

  /// Computed direct HTTPS join URL.
  /// Prioritizes raw joinUrl if present, otherwise constructs from meetingId and passcode.
  String? get computedUrl {
    if (joinUrl != null && joinUrl!.trim().isNotEmpty) {
      return joinUrl!.trim();
    }
    if (meetingId != null && meetingId!.trim().isNotEmpty) {
      final cleanId = meetingId!.replaceAll(RegExp(r'\s+|-'), '');
      if (passcode != null && passcode!.trim().isNotEmpty) {
        return 'https://zoom.us/j/$cleanId?pwd=${Uri.encodeComponent(passcode!.trim())}';
      }
      return 'https://zoom.us/j/$cleanId';
    }
    return null;
  }

  /// Computed native Zoom deep-link URL (`zoomus://`).
  /// Used to attempt direct entry into native Zoom client.
  String? get deepLinkUrl {
    if (meetingId != null && meetingId!.trim().isNotEmpty) {
      final cleanId = meetingId!.replaceAll(RegExp(r'\s+|-'), '');
      if (passcode != null && passcode!.trim().isNotEmpty) {
        return 'zoomus://join?confno=$cleanId&pwd=${Uri.encodeComponent(passcode!.trim())}';
      }
      return 'zoomus://join?confno=$cleanId';
    }

    // Fallback: If only joinUrl exists, attempt to extract confno & pwd or convert scheme
    if (joinUrl != null && joinUrl!.isNotEmpty) {
      final uri = Uri.tryParse(joinUrl!);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final confno = uri.pathSegments.last;
        final pwd = uri.queryParameters['pwd'];
        if (RegExp(r'^\d+$').hasMatch(confno)) {
          if (pwd != null && pwd.isNotEmpty) {
            return 'zoomus://join?confno=$confno&pwd=${Uri.encodeComponent(pwd)}';
          }
          return 'zoomus://join?confno=$confno';
        }
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
        'joinUrl': joinUrl,
        'meetingId': meetingId,
        'passcode': passcode,
      };

  factory ZoomMeeting.fromJson(Map<String, dynamic> json) => ZoomMeeting(
        joinUrl: json['joinUrl'] as String?,
        meetingId: json['meetingId'] as String?,
        passcode: json['passcode'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoomMeeting &&
          runtimeType == other.runtimeType &&
          joinUrl == other.joinUrl &&
          meetingId == other.meetingId &&
          passcode == other.passcode;

  @override
  int get hashCode => Object.hash(joinUrl, meetingId, passcode);

  @override
  String toString() =>
      'ZoomMeeting(meetingId: $meetingId, passcode: ${passcode != null ? '***' : 'none'}, joinUrl: $joinUrl)';
}
