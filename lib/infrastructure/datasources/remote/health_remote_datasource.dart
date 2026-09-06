import '../../../core/constants/api_constants.dart';
import '../../network/dio_client.dart';
import '../../../domain/entities/health_record.dart';
import '../../../domain/enums/sleep_phase.dart';
import '../../../domain/interfaces/repositories/i_health_repository.dart';

/// REST datasource for health/sleep — GET latest, GET sleep breakdown,
/// POST sync (offline buffer flush).
class HealthRemoteDatasource {
  HealthRemoteDatasource(this._dio);
  final DioClient _dio;

  /// GET /dogs/:dogId/health/latest. The backend only returns
  /// {heartRate, temperature, recordedAt} — no id/collarId for this
  /// endpoint, so those are filled with harmless placeholders; callers only
  /// read heartRate/temperature/recordedAt from the result.
  Future<HealthRecord?> getLatest(String dogId) async {
    try {
      final res = await _dio.dio.get<Map<String, dynamic>>(
        ApiConstants.healthLatest(dogId),
      );
      final data = res.data;
      if (data == null) return null;
      return HealthRecord(
        id: 'latest',
        collarId: dogId,
        heartRate: (data['heartRate'] as num?)?.toInt() ?? 0,
        temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
        recordedAt:
            DateTime.tryParse(data['recordedAt'] as String? ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// GET /dogs/:dogId/sleep?days=N.
  Future<SleepBreakdown?> getSleepBreakdown(String dogId, {int days = 1}) async {
    try {
      final res = await _dio.dio.get<Map<String, dynamic>>(
        ApiConstants.healthSleep(dogId, days: days),
      );
      final data = res.data;
      if (data == null) return null;
      final rawPhases = data['phases'] as List<dynamic>? ?? [];
      return SleepBreakdown(
        days: (data['days'] as num?)?.toInt() ?? days,
        totalRecords: (data['totalRecords'] as num?)?.toInt() ?? 0,
        phases: rawPhases.map((e) {
          final m = e as Map<String, dynamic>;
          return SleepPhaseShare(
            phase: _parsePhase(m['phase'] as String?),
            count: (m['count'] as num?)?.toInt() ?? 0,
            percentage: (m['percentage'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  SleepPhase _parsePhase(String? raw) {
    for (final p in SleepPhase.values) {
      if (p.name == raw) return p;
    }
    return SleepPhase.awake;
  }

  /// POST /dogs/:dogId/health/sync with body { records: [...] }.
  /// Each record: heartRate, temperature, steps, activeMinutes, anomalyDetected, anomalyType, recordedAt (ISO).
  /// Returns synced count from response.
  Future<int> syncHealth(
    String dogId,
    List<Map<String, dynamic>> records,
  ) async {
    final res = await _dio.dio.post<Map<String, dynamic>>(
      ApiConstants.healthSync(dogId),
      data: {'records': records},
    );
    final data = res.data;
    return (data?['synced'] as num?)?.toInt() ?? 0;
  }
}
