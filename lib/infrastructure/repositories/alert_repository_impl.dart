import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/alert.dart';
import '../../domain/interfaces/repositories/i_alert_repository.dart';
import '../datasources/remote/alert_remote_datasource.dart';

/// Implémentation alertes MVP : Firestore users/{userId}/alerts.
class AlertRepositoryImpl implements IAlertRepository {
  AlertRepositoryImpl(this._remote, this._auth);
  final AlertRemoteDatasource _remote;
  final FirebaseAuth _auth;

  String get _userId => _auth.currentUser?.uid ?? '';

  @override
  Future<List<Alert>> getAlerts(String dogId, {bool unreadOnly = false, int limit = 50}) async {
    final list = await _remote.getAlerts(_userId, dogId: dogId, unreadOnly: unreadOnly, limit: limit);
    return list.map((e) => e.toEntity()).toList();
  }

  @override
  Future<Alert?> getAlertById(String dogId, String alertId) async {
    final m = await _remote.getAlertById(_userId, alertId);
    return m?.toEntity();
  }

  @override
  Future<Alert> markAsRead(String dogId, String alertId) async {
    final m = await _remote.markAsRead(_userId, alertId);
    return m.toEntity();
  }

  @override
  Future<int> markAllAsRead(String dogId) async {
    return _remote.markAllAsRead(_userId);
  }

  @override
  Future<void> deleteAlert(String dogId, String alertId) async {
    await _remote.deleteAlert(_userId, alertId);
  }
}
