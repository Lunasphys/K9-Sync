import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../models/health_record_model.dart';

/// Datasource santé MVP : Firestore dogs/{dogId}/health_records.
class HealthRemoteDatasourceFirestore {
  HealthRemoteDatasourceFirestore(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _healthCol(String dogId) =>
      _firestore.collection(FirebaseConstants.dogs).doc(dogId).collection(FirebaseConstants.healthRecordsSub);

  Future<HealthRecordModel?> getLatest(String dogId) async {
    final snap = await _healthCol(dogId).orderBy('recordedAt', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return HealthRecordModel.fromFirestore(snap.docs.first);
  }

  Future<List<HealthRecordModel>> getHistory(String dogId, {required DateTime from, required DateTime to}) async {
    final snap = await _healthCol(dogId)
        .where('recordedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('recordedAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('recordedAt', descending: true)
        .get();
    return snap.docs.map((d) => HealthRecordModel.fromFirestore(d)).toList();
  }

  Future<void> addRecords(String dogId, List<HealthRecordModel> records) async {
    final col = _healthCol(dogId);
    for (final r in records) {
      await col.doc(r.id).set(r.toFirestore());
    }
  }
}
