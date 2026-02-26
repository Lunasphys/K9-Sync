/// Shared layout and UI constants. Use for consistent spacing and radii.
abstract final class AppConstants {
  static const double screenPaddingHorizontal = 24;
  static const double cardRadius = 12;
  static const double buttonRadius = 12;

  /// Minimum geofence radius in meters (business rule).
  static const int geofenceRadiusMinM = 10;

  /// GPS retention days (RGPD).
  static const int gpsRetentionDays = 90;

  /// Health data retention months (RGPD).
  static const int healthRetentionMonths = 12;
}
