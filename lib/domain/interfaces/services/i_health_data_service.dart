/// Health data point (e.g. from Health Connect).
class HealthDataPoint {
  final String type;
  final num value;
  final DateTime dateFrom;
  final DateTime dateTo;

  const HealthDataPoint({
    required this.type,
    required this.value,
    required this.dateFrom,
    required this.dateTo,
  });
}

/// Abstraction for Health Connect / Samsung Health — read FC, steps, sleep.
abstract interface class IHealthDataService {
  Future<bool> requestAuthorization(List<String> typeIds);
  Future<List<HealthDataPoint>> getHealthDataFromTypes(
    DateTime from,
    DateTime to,
    List<String> typeIds,
  );
}
