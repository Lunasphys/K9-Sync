import '../entities/alert_entity.dart';

/// Abstract repository for alerts (Clean Architecture – domain defines the contract).
abstract interface class AlertsRepository {
  /// Fetches alerts, optionally filtered by priority.
  Future<List<AlertEntity>> getAlerts({bool priorityOnly = false});
}
