import '../../domain/entities/health_record.dart';
import '../../domain/interfaces/repositories/i_health_repository.dart';

/// Get health history for a dog.
class GetHealthRecordsUseCase {
  final IHealthRepository _repo;

  GetHealthRecordsUseCase(this._repo);

  Future<List<HealthRecord>> call(
    String dogId, {
    required DateTime from,
    required DateTime to,
  }) =>
      _repo.getHealthHistory(dogId, from: from, to: to);
}
