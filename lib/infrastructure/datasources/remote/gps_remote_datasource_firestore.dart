import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../models/gps_location_model.dart';

/// Datasource GPS MVP : Firestore dogs/{dogId}/gps_locations (MVP = téléphone, dogId lié au chien suivi).
class GpsRemoteDatasourceFirestore {
  GpsRemoteDatasourceFirestore(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _gpsCol(String dogId) =>
      _firestore.collection(FirebaseConstants.dogs).doc(dogId).collection(FirebaseConstants.gpsLocationsSub);

  Future<GpsLocationModel?> getLatest(String dogId) async {
    final snap = await _gpsCol(dogId).orderBy('recordedAt', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return GpsLocationModel.fromFirestore(snap.docs.first);
  }

  Future<List<GpsLocationModel>> getHistory(
    String dogId, {
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) async {
    final snap = await _gpsCol(dogId)
        .where('recordedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('recordedAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('recordedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => GpsLocationModel.fromFirestore(d)).toList();
  }

  Future<void> addLocations(String dogId, List<GpsLocationModel> locations) async {
    final col = _gpsCol(dogId);
    for (final loc in locations) {
      await col.doc(loc.id).set(loc.toFirestore()..['recordedAt'] = Timestamp.fromDate(loc.recordedAt));
    }
  }
}
