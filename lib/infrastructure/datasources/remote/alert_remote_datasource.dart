import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../models/alert_model.dart';

/// Datasource alertes MVP : Firestore users/{userId}/alerts. Si [_firestore] null (sans Firebase), retourne vide / no-op.
class AlertRemoteDatasource {
  AlertRemoteDatasource(this._firestore);
  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>>? _alertsCol(String userId) {
    if (_firestore == null) return null;
    return _firestore!
        .collection(FirebaseConstants.users)
        .doc(userId)
        .collection(FirebaseConstants.alertsSub);
  }

  Future<List<AlertModel>> getAlerts(String userId, {String? dogId, bool unreadOnly = false, int limit = 50}) async {
    final col = _alertsCol(userId);
    if (col == null) return [];
    var query = col.orderBy('triggeredAt', descending: true).limit(limit);
    if (dogId != null && dogId.isNotEmpty) query = query.where('dogId', isEqualTo: dogId);
    if (unreadOnly) query = query.where('isRead', isEqualTo: false);
    final snap = await query.get();
    return snap.docs.map((d) => AlertModel.fromFirestore(d)).toList();
  }

  Future<AlertModel?> getAlertById(String userId, String alertId) async {
    final col = _alertsCol(userId);
    if (col == null) return null;
    final doc = await col.doc(alertId).get();
    if (!doc.exists) return null;
    return AlertModel.fromFirestore(doc);
  }

  Future<AlertModel> markAsRead(String userId, String alertId) async {
    final col = _alertsCol(userId);
    if (col == null) throw UnimplementedError('Firebase non configuré');
    await col.doc(alertId).update({'isRead': true});
    final doc = await col.doc(alertId).get();
    return AlertModel.fromFirestore(doc);
  }

  Future<int> markAllAsRead(String userId) async {
    final col = _alertsCol(userId);
    if (col == null) return 0;
    final snap = await col.where('isRead', isEqualTo: false).get();
    for (final d in snap.docs) {
      await d.reference.update({'isRead': true});
    }
    return snap.docs.length;
  }

  Future<void> deleteAlert(String userId, String alertId) async {
    final col = _alertsCol(userId);
    if (col == null) return;
    await col.doc(alertId).delete();
  }
}
