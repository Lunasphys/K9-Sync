import '../../entities/health_record.dart';
import '../../enums/sleep_phase.dart';

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

/// Share of ActivityRecord snapshots in one sleep phase over a period —
/// a proxy for time spent in it (each record is a discrete point, not a
/// duration).
class SleepPhaseShare {
  final SleepPhase phase;
  final int count;
  final double percentage;

  const SleepPhaseShare({
    required this.phase,
    required this.count,
    required this.percentage,
  });
}

/// Sleep phase breakdown over the last [days] (API response — GET .../sleep).
class SleepBreakdown {
  final int days;
  final int totalRecords;
  final List<SleepPhaseShare> phases;

  const SleepBreakdown({
    required this.days,
    required this.totalRecords,
    required this.phases,
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

  /// Sleep phase breakdown (GET /dogs/:dogId/sleep) over the last [days].
  Future<SleepBreakdown?> getSleepBreakdown(String dogId, {int days = 1});
  Future<List<AnomalyRecord>> getAnomalies(
    String dogId, {
    DateTime? from,
    DateTime? to,
  });
  Future<int> syncOfflineHealth(String dogId, List<HealthRecord> records);
  Future<List<int>> exportPdfBytes(
    String dogId, {
    DateTime? from,
    DateTime? to,
  });
}
