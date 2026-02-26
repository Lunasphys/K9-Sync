/// Local storage for health records (offline). Stub for skeleton.
abstract class HealthLocalDatasource {
  Future<void> saveOfflineRecords(String dogId, List<Map<String, dynamic>> records);
  Future<List<Map<String, dynamic>>> getOfflineRecords(String dogId);
  Future<void> clearSynced(String dogId, List<String> syncedIds);
}

class HealthLocalDatasourceImpl implements HealthLocalDatasource {
  @override
  Future<void> saveOfflineRecords(String dogId, List<Map<String, dynamic>> records) async {}

  @override
  Future<List<Map<String, dynamic>>> getOfflineRecords(String dogId) async => [];

  @override
  Future<void> clearSynced(String dogId, List<String> syncedIds) async {}
}
