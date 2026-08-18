/// Deterministic 32-bit hash utility for generating stable notification IDs.
/// ponytail: Replaces the need for a local SQLite database mapping table.
/// Given the same eventId and start timestamp, always produces the exact same integer ID.
class DeterministicHash {
  DeterministicHash._();

  /// Returns a positive 31-bit integer suitable for Android/iOS notification IDs.
  static int hash(String input) {
    var hash = 5381;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      // Keep within 32-bit signed integer range
      hash = hash & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Convenience helper for event + timestamp combination.
  static int forEvent(String eventId, DateTime startTime) {
    return hash('${eventId}_${startTime.millisecondsSinceEpoch}');
  }
}
