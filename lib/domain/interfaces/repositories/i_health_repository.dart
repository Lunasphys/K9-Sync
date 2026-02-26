import '../../entities/health_record.dart';

/// Activity summary for a day (API response).
class ActivitySummary {
  final int steps;
  final int activeMinutes;
  final int restMinutes;
  final DateTime date;

  const ActivitySummary({
    required this.steps,
    required this.activeMinutes,
    required this.restMinutes,
    required this.date,
  });
}

/// Sleep analysis for a day (API response).
class SleepAnalysis {
  final Duration totalSleep;
  final Duration deepSleep;
  final Duration lightSleep;
  final DateTime date;

  const SleepAnalysis({
    required this.totalSleep,
    required this.deepSleep,
    required this.lightSleep,
    required this.date,
  });
}

/// Anomaly record (API response).
class AnomalyRecord {
  final String id;
  final String type;
  final String? message;
  final DateTime recordedAt;

  const AnomalyRecord({
    required this.id,
    required this.type,
    this.message,
    required this.recordedAt,
  });
}

/// Contract for health data (Clean Architecture — domain).
abstract interface class IHealthRepository {
  Future<HealthRecord?> getLatestHealth(String dogId);
  Future<List<HealthRecord>> getHealthHistory(
    String dogId, {
    required DateTime from,
    required DateTime to,
  });
  Future<ActivitySummary?> getActivitySummary(String dogId, DateTime date);
  Future<SleepAnalysis?> getSleepAnalysis(String dogId, DateTime date);
  Future<List<AnomalyRecord>> getAnomalies(
    String dogId, {
    DateTime? from,
    DateTime? to,
  });
  Future<int> syncOfflineHealth(String dogId, List<HealthRecord> records);
  Future<List<int>> exportPdfBytes(String dogId, {DateTime? from, DateTime? to});
}
