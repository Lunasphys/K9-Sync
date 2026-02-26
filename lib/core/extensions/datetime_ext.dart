/// Extensions on [DateTime].
extension DateTimeExt on DateTime {
  /// Start of day in local time.
  DateTime get startOfDay => DateTime(year, month, day);

  /// End of day in local time (23:59:59.999).
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// ISO 8601 UTC string for API query params.
  String toIso8601Utc() => toUtc().toIso8601String();

  /// Format for API date query (YYYY-MM-DD).
  String toApiDateString() {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}
