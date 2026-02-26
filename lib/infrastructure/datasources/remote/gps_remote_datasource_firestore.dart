import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../models/gps_location_model.dart';

/// Datasource GPS MVP : Firestore dogs/{dogId}/gps_locations. Si [_firestore] null (sans Firebase), retourne vide / no-op.
class GpsRemoteDatasourceFirestore {
  GpsRemoteDatasourceFirestore(this._firestore);
  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>>? _gpsCol(String dogId) {
    if (_firestore == null) return null;
    return _firestore!.collection(FirebaseConstants.dogs).doc(dogId).collection(FirebaseConstants.gpsLocationsSub);
  }

  Future<GpsLocationModel?> getLatest(String dogId) async {
    final col = _gpsCol(dogId);
    if (col == null) return null;
    final snap = await col.orderBy('recordedAt', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return GpsLocationModel.fromFirestore(snap.docs.first);
  }

  Future<List<GpsLocationModel>> getHistory(
    String dogId, {
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) async {
    final col = _gpsCol(dogId);
    if (col == null) return [];
    final snap = await col
        .where('recordedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('recordedAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('recordedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => GpsLocationModel.fromFirestore(d)).toList();
  }

  Future<void> addLocations(String dogId, List<GpsLocationModel> locations) async {
    final col = _gpsCol(dogId);
    if (col == null) return;
    for (final loc in locations) {
      await col.doc(loc.id).set(loc.toFirestore()..['recordedAt'] = Timestamp.fromDate(loc.recordedAt));
    }
  }
}
