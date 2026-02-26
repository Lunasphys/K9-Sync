import '../../domain/entities/alert.dart';
import '../../domain/interfaces/repositories/i_alert_repository.dart';

/// Get alerts for a dog.
class GetAlertsUseCase {
  final IAlertRepository _repo;

  GetAlertsUseCase(this._repo);

  Future<List<Alert>> call(String dogId, {bool unreadOnly = false, int limit = 50}) =>
      _repo.getAlerts(dogId, unreadOnly: unreadOnly, limit: limit);
}
