import '../../entities/alert.dart';

/// Contract for alerts (Clean Architecture — domain).
abstract interface class IAlertRepository {
  Future<List<Alert>> getAlerts(
    String dogId, {
    bool unreadOnly = false,
    int limit = 50,
  });
  Future<Alert?> getAlertById(String dogId, String alertId);
  Future<Alert> markAsRead(String dogId, String alertId);
  Future<int> markAllAsRead(String dogId);
  Future<void> deleteAlert(String dogId, String alertId);
}
