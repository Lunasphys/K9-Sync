import '../../../core/constants/api_constants.dart';
import '../../network/dio_client.dart';

/// REST datasource for health sync only. POSTs to /dogs/:dogId/health/sync.
class HealthRemoteDatasource {
  HealthRemoteDatasource(this._dio);
  final DioClient _dio;

  /// POST /dogs/:dogId/health/sync with body { records: [...] }.
  /// Each record: heartRate, temperature, steps, activeMinutes, anomalyDetected, anomalyType, recordedAt (ISO).
  /// Returns synced count from response.
  Future<int> syncHealth(String dogId, List<Map<String, dynamic>> records) async {
    final res = await _dio.dio.post<Map<String, dynamic>>(
      ApiConstants.healthSync(dogId),
      data: {'records': records},
    );
    final data = res.data;
    return (data?['synced'] as num?)?.toInt() ?? 0;
  }
}
