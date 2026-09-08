import '../../entities/gps_location.dart';
import '../../entities/trail.dart';

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

  /// Creates the trail summary server-side (POST /dogs/:dogId/trails) and
  /// returns the backend-assigned trail id, used to link this trail's GPS
  /// points when syncing them via [syncOfflineLocations].
  Future<String> createTrail(String dogId, Trail trail);

  /// [trailId], when given, links the synced points to that trail
  /// server-side (see POST /dogs/:dogId/gps/sync).
  Future<int> syncOfflineLocations(
    String dogId,
    List<GpsLocation> locations, {
    String? trailId,
  });
}
