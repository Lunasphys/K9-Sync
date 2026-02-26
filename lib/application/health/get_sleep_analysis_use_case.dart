import '../../domain/interfaces/repositories/i_health_repository.dart';

/// Get sleep analysis for a dog on a given date.
class GetSleepAnalysisUseCase {
  final IHealthRepository _repo;

  GetSleepAnalysisUseCase(this._repo);

  Future<SleepAnalysis?> call(String dogId, DateTime date) =>
      _repo.getSleepAnalysis(dogId, date);
}
