import '../../domain/entities/gps_location.dart';
import '../../domain/interfaces/repositories/i_gps_repository.dart';

/// Sync offline GPS points to backend.
class SyncOfflineDataUseCase {
  final IGpsRepository _repo;

  SyncOfflineDataUseCase(this._repo);

  Future<int> call(String dogId, List<GpsLocation> locations) =>
      _repo.syncOfflineLocations(dogId, locations);
}
