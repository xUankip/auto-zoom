import '../models/zoom_meeting.dart';

/// Zoom credentials parser pipeline.
/// Implements priority-based parsing with strict numeric validation.
/// ponytail: Single unified pipeline without heavy NLP or third-party parsing dependencies.
class ZoomParser {
  ZoomParser._();

  // 1. Direct Zoom Join/Webinar URL (supports standard zoom.us, subdomains like us02web.zoom.us, vanity URLs)
  static final RegExp _zoomUrlRegex = RegExp(
    r'https?://(?:[a-zA-Z0-9-]+\.)?zoom\.(?:us|com)/(?:j|w|my)/([a-zA-Z0-9._-]+)(?:\?[^\s\n\r<>"'
    r"']*)?",
    caseSensitive: false,
  );

  // 2. Query param for password in Zoom URL
  static final RegExp _pwdParamRegex = RegExp(
    r'[?&]pwd=([a-zA-Z0-9._~-]+)',
    caseSensitive: false,
  );

  // 3. Meeting ID patterns in English & Vietnamese
  static final RegExp _meetingIdRegex = RegExp(
    r'(?:Meeting\s*ID|Zoom\s*ID|ID\s*phòng|Mã\s*phòng|Mã\s*cuộc\s*họp|ID|Phòng|Zoom)\s*[:：\-]?\s*([0-9\s\-]{9,17})',
    caseSensitive: false,
  );

  // 4. Passcode / Password patterns in English & Vietnamese
  static final RegExp _passcodeRegex = RegExp(
    r'(?:Passcode|Password|Pass|Mật\s*khẩu|Mã\s*bảo\s*mật|Mật\s*mã|Mã\s*vào\s*phòng|pwd)\s*[:：\-]?\s*([^\s\n\r,;]{3,32})',
    caseSensitive: false,
  );

  /// Validates that a candidate meeting ID consists strictly of 9 to 11 digits.
  static bool isValidMeetingId(String? id) {
    if (id == null) return false;
    final digitsOnly = id.replaceAll(RegExp(r'\s+|-'), '');
    return RegExp(r'^\d{9,11}$').hasMatch(digitsOnly);
  }

  /// Parses text from location, description, or title and returns a validated [ZoomMeeting].
  static ZoomMeeting? parse({
    String? location,
    String? description,
    String? title,
  }) {
    // Combine all fields into a searchable body
    final rawText = '${location ?? ""}\n${description ?? ""}\n${title ?? ""}';
    if (rawText.trim().isEmpty) return null;

    // --- PRIORITY 1: Direct Zoom URL ---
    final urlMatch = _zoomUrlRegex.firstMatch(rawText);
    if (urlMatch != null) {
      final rawUrl = urlMatch.group(0)!;
      final candidateId = urlMatch.group(1)!;

      // Extract pwd parameter if present
      final pwdMatch = _pwdParamRegex.firstMatch(rawUrl);
      final passcode = pwdMatch?.group(1);

      // Sanitize candidate ID (if numeric)
      final digitsId = candidateId.replaceAll(RegExp(r'\s+|-'), '');
      final meetingId = isValidMeetingId(digitsId) ? digitsId : null;

      return ZoomMeeting(
        joinUrl: rawUrl,
        meetingId: meetingId,
        passcode: passcode,
      );
    }

    // --- PRIORITY 2: Explicit Meeting ID (+ optional Passcode) ---
    final idMatches = _meetingIdRegex.allMatches(rawText);
    for (final match in idMatches) {
      final rawId = match.group(1);
      if (rawId == null) continue;

      final digitsOnly = rawId.replaceAll(RegExp(r'\s+|-'), '');
      if (isValidMeetingId(digitsOnly)) {
        // Look for passcode anywhere in the text
        String? passcode;
        final passMatch = _passcodeRegex.firstMatch(rawText);
        if (passMatch != null) {
          final rawPass = passMatch.group(1)?.trim();
          if (rawPass != null && rawPass.isNotEmpty) {
            // Remove any trailing punct
            passcode = rawPass.replaceAll(RegExp(r'[.,;!)]+$'), '');
          }
        }

        return ZoomMeeting(
          meetingId: digitsOnly,
          passcode: passcode,
          joinUrl: passcode != null && passcode.isNotEmpty
              ? 'https://zoom.us/j/$digitsOnly?pwd=${Uri.encodeComponent(passcode)}'
              : 'https://zoom.us/j/$digitsOnly',
        );
      }
    }

    return null;
  }
}
