import '../../domain/entities/health_record.dart';
import '../../domain/interfaces/repositories/i_health_repository.dart';

/// Sync offline health snapshots from Hive to the backend.
class SyncOfflineHealthUseCase {
  final IHealthRepository _repo;

  SyncOfflineHealthUseCase(this._repo);

  Future<int> call(String dogId) =>
      _repo.syncOfflineHealth(dogId, <HealthRecord>[]);
}
