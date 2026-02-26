/// Extensions on [String].
extension StringExt on String {
  /// Returns true if this string is not empty after trim.
  bool get isNotBlank => trim().isNotEmpty;

  /// Capitalize first letter only.
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
