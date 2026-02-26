import '../../domain/entities/alert.dart';
import '../../domain/interfaces/repositories/i_alert_repository.dart';

/// Marque une alerte comme lue.
class MarkAlertReadUseCase {
  MarkAlertReadUseCase(this._repo);
  final IAlertRepository _repo;

  Future<Alert> call(String dogId, String alertId) => _repo.markAsRead(dogId, alertId);
}
