import '../../domain/interfaces/services/i_health_data_service.dart';

/// Health Connect (Android) / HealthKit implementation — stub. Use package health.
class HealthConnectService implements IHealthDataService {
  @override
  Future<bool> requestAuthorization(List<String> typeIds) async => false;

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes(
    DateTime from,
    DateTime to,
    List<String> typeIds,
  ) async =>
      [];
}
