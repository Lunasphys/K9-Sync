import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../models/alert_model.dart';

/// Datasource alertes MVP : Firestore users/{userId}/alerts.
class AlertRemoteDatasource {
  AlertRemoteDatasource(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _alertsCol(String userId) =>
      _firestore.collection(FirebaseConstants.users).doc(userId).collection(FirebaseConstants.alertsSub);

  Future<List<AlertModel>> getAlerts(String userId, {String? dogId, bool unreadOnly = false, int limit = 50}) async {
    var query = _alertsCol(userId).orderBy('triggeredAt', descending: true).limit(limit);
    if (dogId != null && dogId.isNotEmpty) query = query.where('dogId', isEqualTo: dogId);
    if (unreadOnly) query = query.where('isRead', isEqualTo: false);
    final snap = await query.get();
    return snap.docs.map((d) => AlertModel.fromFirestore(d)).toList();
  }

  Future<AlertModel?> getAlertById(String userId, String alertId) async {
    final doc = await _alertsCol(userId).doc(alertId).get();
    if (!doc.exists) return null;
    return AlertModel.fromFirestore(doc);
  }

  Future<AlertModel> markAsRead(String userId, String alertId) async {
    await _alertsCol(userId).doc(alertId).update({'isRead': true});
    final doc = await _alertsCol(userId).doc(alertId).get();
    return AlertModel.fromFirestore(doc);
  }

  Future<int> markAllAsRead(String userId) async {
    final snap = await _alertsCol(userId).where('isRead', isEqualTo: false).get();
    for (final d in snap.docs) {
      await d.reference.update({'isRead': true});
    }
    return snap.docs.length;
  }

  Future<void> deleteAlert(String userId, String alertId) async {
    await _alertsCol(userId).doc(alertId).delete();
  }
}
