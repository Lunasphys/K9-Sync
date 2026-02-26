import '../../domain/entities/alert.dart';
import '../../domain/interfaces/repositories/i_alert_repository.dart';
import '../../domain/interfaces/repositories/i_auth_repository.dart';
import '../datasources/remote/alert_remote_datasource.dart';

/// Implémentation alertes : Firestore users/{userId}/alerts. UserId depuis auth (Firebase ou REST).
class AlertRepositoryImpl implements IAlertRepository {
  AlertRepositoryImpl(this._remote, this._authRepo);
  final AlertRemoteDatasource _remote;
  final IAuthRepository _authRepo;

  Future<String> get _userId async => (await _authRepo.getCurrentUser())?.id ?? '';

  @override
  Future<List<Alert>> getAlerts(String dogId, {bool unreadOnly = false, int limit = 50}) async {
    final uid = await _userId;
    final list = await _remote.getAlerts(uid, dogId: dogId, unreadOnly: unreadOnly, limit: limit);
    return list.map((e) => e.toEntity()).toList();
  }

  @override
  Future<Alert?> getAlertById(String dogId, String alertId) async {
    final uid = await _userId;
    final m = await _remote.getAlertById(uid, alertId);
    return m?.toEntity();
  }

  @override
  Future<Alert> markAsRead(String dogId, String alertId) async {
    final uid = await _userId;
    final m = await _remote.markAsRead(uid, alertId);
    return m.toEntity();
  }

  @override
  Future<int> markAllAsRead(String dogId) async {
    final uid = await _userId;
    return _remote.markAllAsRead(uid);
  }

  @override
  Future<void> deleteAlert(String dogId, String alertId) async {
    final uid = await _userId;
    await _remote.deleteAlert(uid, alertId);
  }
}
