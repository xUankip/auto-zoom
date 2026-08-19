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
// PtitClass – a single subject slot from the API
// ---------------------------------------------------------------------------

class PtitClass {
  /// Subject code, e.g. "INT3301"
  final String subjectCode;

  /// Subject name in Vietnamese
  final String subjectName;

  /// Room / location
  final String room;

  /// Lecturer name
  final String lecturer;

  /// Date string from API, e.g. "12/08/2025"
  final String dateStr;

  /// Start period (tiết bắt đầu, 1-based). Periods map to clock times.
  final int startPeriod;

  /// End period (tiết kết thúc, 1-based).
  final int endPeriod;

  /// Week number within the semester.
  final int weekIndex;

  const PtitClass({
    required this.subjectCode,
    required this.subjectName,
    required this.room,
    required this.lecturer,
    required this.dateStr,
    required this.startPeriod,
    required this.endPeriod,
    required this.weekIndex,
  });

  factory PtitClass.fromJson(Map<String, dynamic> json) {
    // Field names observed from the PTIT JS bundle analysis:
    // ma_mon, ten_mon, phong, giang_vien, ngay_hoc, tiet_bat_dau, so_tiet
    final startPeriod = _parseInt(json['tiet_bat_dau']);
    final soTiet = _parseInt(json['so_tiet'] ?? json['so_tiet_hoc']);
    final endPeriod = startPeriod + (soTiet > 0 ? soTiet - 1 : 0);

    return PtitClass(
      subjectCode: _str(json['ma_mon'] ?? json['ma_mh'] ?? ''),
      subjectName: _str(json['ten_mon'] ?? json['ten_mh'] ?? json['mon_hoc'] ?? ''),
      room: _str(json['phong'] ?? json['phong_hoc'] ?? ''),
      lecturer: _str(json['giang_vien'] ?? json['ten_gv'] ?? ''),
      dateStr: _str(json['ngay_hoc'] ?? json['ngay'] ?? ''),
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      weekIndex: _parseInt(json['tuan'] ?? json['so_tuan'] ?? 0),
    );
  }

  static String _str(dynamic v) => v?.toString().trim() ?? '';
  static int _parseInt(dynamic v) =>
      v == null ? 0 : int.tryParse(v.toString()) ?? 0;

  @override
  String toString() =>
      'PtitClass($subjectCode, $dateStr, t$startPeriod-t$endPeriod, $room)';
}

// ---------------------------------------------------------------------------
// Period → Clock time mapping (PTIT standard)
// ---------------------------------------------------------------------------

/// Maps period number (1-based) to [hour, minute] of its START time.
const Map<int, List<int>> kPtitPeriodStart = {
  1: [7, 0],
  2: [8, 0],
  3: [9, 0],
  4: [10, 0],
  5: [11, 0],
  6: [12, 30],
  7: [13, 30],
  8: [14, 30],
  9: [15, 30],
  10: [16, 30],
  11: [17, 30],
  12: [18, 30],
  13: [19, 30],
  14: [20, 30],
};

/// Maps period number (1-based) to [hour, minute] of its END time.
const Map<int, List<int>> kPtitPeriodEnd = {
  1: [7, 50],
  2: [8, 50],
  3: [9, 50],
  4: [10, 50],
  5: [11, 50],
  6: [13, 20],
  7: [14, 20],
  8: [15, 20],
  9: [16, 20],
  10: [17, 20],
  11: [18, 20],
  12: [19, 20],
  13: [20, 20],
  14: [21, 20],
};
