/// Domain models for the PTIT timetable API.
library;

// ---------------------------------------------------------------------------
// Session (auth result)
// ---------------------------------------------------------------------------

class PtitSession {
  final String accessToken;
  final String studentCode;
  final String studentName;

  const PtitSession({
    required this.accessToken,
    required this.studentCode,
    required this.studentName,
  });
}

// ---------------------------------------------------------------------------
// PtitClass – one lesson slot from the API's ds_thoi_khoa_bieu
// ---------------------------------------------------------------------------

class PtitClass {
  /// Subject code, e.g. "INT1154"
  final String subjectCode;

  /// Subject name in Vietnamese, e.g. "Tin học cơ sở 1"
  final String subjectName;

  /// Room / location field (may contain Zoom info in old format)
  final String room;

  /// Lecturer name
  final String lecturer;

  /// ISO 8601 date string from API, e.g. "2026-09-21T00:00:00"
  final String ngayHoc;

  /// Start period (tiết bắt đầu, 1-based).
  final int startPeriod;

  /// Number of periods (so_tiet).
  final int soTiet;

  /// Computed end period.
  int get endPeriod => startPeriod + soTiet - 1;

  /// Week number within the semester (1-based).
  final int weekIndex;

  /// Online meeting URL (link_hoc_online) – may be Zoom deep link.
  final String? linkHocOnline;

  /// Class name (ten_lop)
  final String tenLop;

  const PtitClass({
    required this.subjectCode,
    required this.subjectName,
    required this.room,
    required this.lecturer,
    required this.ngayHoc,
    required this.startPeriod,
    required this.soTiet,
    required this.weekIndex,
    this.linkHocOnline,
    this.tenLop = '',
  });

  factory PtitClass.fromJson(
    Map<String, dynamic> json, {
    int weekIndex = 0,
    String weekStartDate = '',
  }) {
    final startPeriod = _parseInt(json['tiet_bat_dau']);
    final soTiet = _parseInt(json['so_tiet'] ?? 1);

    return PtitClass(
      subjectCode: _str(json['ma_mon']),
      subjectName: _str(json['ten_mon']),
      room: _str(json['ma_phong']),
      lecturer: _str(json['ten_giang_vien']),
      ngayHoc: _str(json['ngay_hoc']),
      startPeriod: startPeriod,
      soTiet: soTiet > 0 ? soTiet : 1,
      weekIndex: _parseInt(json['tuan_hoc_ky'] ?? weekIndex),
      linkHocOnline: (json['link_hoc_online'] as String?)?.trim().isNotEmpty == true
          ? (json['link_hoc_online'] as String).trim()
          : null,
      tenLop: _str(json['ten_lop']),
    );
  }

  /// Parse ngay_hoc to a DateTime. Handles ISO 8601 format from API.
  DateTime? get date {
    if (ngayHoc.isEmpty) return null;
    try {
      return DateTime.parse(ngayHoc);
    } catch (_) {
      return null;
    }
  }

  static String _str(dynamic v) => v?.toString().trim() ?? '';
  static int _parseInt(dynamic v) =>
      v == null ? 0 : int.tryParse(v.toString()) ?? 0;

  @override
  String toString() =>
      'PtitClass($subjectCode, $ngayHoc, t$startPeriod, so_tiet=$soTiet)';
}

// ---------------------------------------------------------------------------
// Period → Clock time mapping  (source: ds_tiet_trong_ngay from PTIT API)
// Each period = 50 minutes.  Tiết 1 starts 07:00, tiết N starts at 07:00 + (N-1)×60min.
// Confirmed from API: 07:00, 08:00, 09:00, 10:00, 11:00, 12:00, 13:00, 14:00,
//                    15:00, 16:00, 17:00, 18:00, 19:00, 20:00, 21:00
// ---------------------------------------------------------------------------

/// Start time [hour, minute] for each period (Vietnam time / UTC+7).
const Map<int, List<int>> kPtitPeriodStart = {
  1:  [7,  0],
  2:  [8,  0],
  3:  [9,  0],
  4:  [10, 0],
  5:  [11, 0],
  6:  [12, 0],
  7:  [13, 0],
  8:  [14, 0],
  9:  [15, 0],
  10: [16, 0],
  11: [17, 0],
  12: [18, 0],
  13: [19, 0],
  14: [20, 0],
  15: [21, 0],
};

/// End time [hour, minute] for each period (Vietnam time / UTC+7).
const Map<int, List<int>> kPtitPeriodEnd = {
  1:  [7,  50],
  2:  [8,  50],
  3:  [9,  50],
  4:  [10, 50],
  5:  [11, 50],
  6:  [12, 50],
  7:  [13, 50],
  8:  [14, 50],
  9:  [15, 50],
  10: [16, 50],
  11: [17, 50],
  12: [18, 50],
  13: [19, 50],
  14: [20, 50],
  15: [21, 50],
};

