import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../models/health_record_model.dart';

/// Datasource santé MVP : Firestore dogs/{dogId}/health_records. Si [_firestore] null (sans Firebase), retourne vide / no-op.
class HealthRemoteDatasourceFirestore {
  HealthRemoteDatasourceFirestore(this._firestore);
  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>>? _healthCol(String dogId) {
    if (_firestore == null) return null;
    return _firestore!
        .collection(FirebaseConstants.dogs)
        .doc(dogId)
        .collection(FirebaseConstants.healthRecordsSub);
  }

  Future<HealthRecordModel?> getLatest(String dogId) async {
    final col = _healthCol(dogId);
    if (col == null) return null;
    final snap = await col.orderBy('recordedAt', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return HealthRecordModel.fromFirestore(snap.docs.first);
  }

  Future<List<HealthRecordModel>> getHistory(String dogId, {required DateTime from, required DateTime to}) async {
    final col = _healthCol(dogId);
    if (col == null) return [];
    final snap = await col
        .where('recordedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('recordedAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('recordedAt', descending: true)
        .get();
    return snap.docs.map((d) => HealthRecordModel.fromFirestore(d)).toList();
  }

  Future<void> addRecords(String dogId, List<HealthRecordModel> records) async {
    final col = _healthCol(dogId);
    if (col == null) return;
    for (final r in records) {
      await col.doc(r.id).set(r.toFirestore());
    }
  }
}
