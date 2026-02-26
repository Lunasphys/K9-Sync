import '../../domain/entities/health_record.dart';
import '../../domain/interfaces/repositories/i_health_repository.dart';
import '../datasources/remote/health_remote_datasource_firestore.dart';

/// Implémentation santé MVP : Firestore dogs/{dogId}/health_records.
class HealthRepositoryImpl implements IHealthRepository {
  HealthRepositoryImpl(this._remote);
  final HealthRemoteDatasourceFirestore _remote;

  @override
  Future<HealthRecord?> getLatestHealth(String dogId) async {
    final m = await _remote.getLatest(dogId);
    return m?.toEntity();
  }

  @override
  Future<List<HealthRecord>> getHealthHistory(
    String dogId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final list = await _remote.getHistory(dogId, from: from, to: to);
    return list.map((e) => e.toEntity()).toList();
  }

  @override
  Future<ActivitySummary?> getActivitySummary(String dogId, DateTime date) async => null;

  @override
  Future<SleepAnalysis?> getSleepAnalysis(String dogId, DateTime date) async => null;

  @override
  Future<List<AnomalyRecord>> getAnomalies(String dogId, {DateTime? from, DateTime? to}) async => [];

  @override
  Future<int> syncOfflineHealth(String dogId, List<HealthRecord> records) async => 0;

  @override
  Future<List<int>> exportPdfBytes(String dogId, {DateTime? from, DateTime? to}) async => [];
}
