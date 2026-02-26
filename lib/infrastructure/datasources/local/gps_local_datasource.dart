/// Local storage for GPS points (offline). Use Hive or Isar — stub for skeleton.
abstract class GpsLocalDatasource {
  Future<void> saveOfflinePoints(String dogId, List<Map<String, dynamic>> points);
  Future<List<Map<String, dynamic>>> getOfflinePoints(String dogId);
  Future<void> clearSynced(String dogId, List<String> syncedIds);
}

/// Stub implementation.
class GpsLocalDatasourceImpl implements GpsLocalDatasource {
  @override
  Future<void> saveOfflinePoints(String dogId, List<Map<String, dynamic>> points) async {
    // TODO: Hive box
  }

  @override
  Future<List<Map<String, dynamic>>> getOfflinePoints(String dogId) async => [];

  @override
  Future<void> clearSynced(String dogId, List<String> syncedIds) async {}
}
