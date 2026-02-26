import '../../domain/interfaces/repositories/i_health_repository.dart';

/// Get anomalies for a dog (detection results).
class DetectAnomalyUseCase {
  final IHealthRepository _repo;

  DetectAnomalyUseCase(this._repo);

  Future<List<AnomalyRecord>> call(String dogId, {DateTime? from, DateTime? to}) =>
      _repo.getAnomalies(dogId, from: from, to: to);
}
