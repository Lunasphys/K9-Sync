import '../../entities/gps_location.dart';

/// Contract for GPS / location data (Clean Architecture — domain).
abstract interface class IGpsRepository {
  Future<GpsLocation?> getLatestLocation(String dogId);
  Future<List<GpsLocation>> getLocationHistory(
    String dogId, {
    required DateTime from,
    required DateTime to,
    int limit = 500,
  });
  Future<List<Trail>> getTrails(String dogId, {DateTime? from, DateTime? to});
  Future<Trail?> getTrailById(String dogId, String trailId);
  Future<int> syncOfflineLocations(String dogId, List<GpsLocation> locations);
}
