import 'dart:math' as math;

/// GPS / location utilities (distance, bearing, etc.).
abstract final class GpsUtils {
  /// Earth radius in meters (WGS84 approx).
  static const double earthRadiusM = 6371000;

  /// Haversine distance between two points in meters.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  /// Bearing in degrees (0 = North, 90 = East).
  static double bearing(double lat1, double lng1, double lat2, double lng2) {
    final rLat1 = _toRad(lat1);
    final rLat2 = _toRad(lat2);
    final dLng = _toRad(lng2 - lng1);
    final x = math.sin(dLng) * math.cos(rLat2);
    final y = math.cos(rLat1) * math.sin(rLat2) - math.sin(rLat1) * math.cos(rLat2) * math.cos(dLng);
    final b = math.atan2(x, y) * 180 / math.pi;
    return (b + 360) % 360;
  }
}
