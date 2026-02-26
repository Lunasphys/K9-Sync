import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../models/dog_model.dart';

/// Datasource chiens MVP : Firestore users/{userId}/dogs. Si [_firestore] est null (sans Firebase), retourne vide / no-op.
class DogRemoteDatasource {
  DogRemoteDatasource(this._firestore);
  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>>? _dogsCol(String userId) {
    if (_firestore == null) return null;
    return _firestore!
        .collection(FirebaseConstants.users)
        .doc(userId)
        .collection(FirebaseConstants.dogsSub);
  }

  Future<List<DogModel>> getDogs(String userId) async {
    final col = _dogsCol(userId);
    if (col == null) return [];
    final snap = await col.orderBy(FirebaseConstants.updatedAt, descending: true).get();
    return snap.docs.map((d) => DogModel.fromFirestore(d)).toList();
  }

  Future<DogModel?> getDogById(String userId, String dogId) async {
    final col = _dogsCol(userId);
    if (col == null) return null;
    final doc = await col.doc(dogId).get();
    if (!doc.exists) return null;
    return DogModel.fromFirestore(doc);
  }

  Future<DogModel> createDog(String userId, Map<String, dynamic> data) async {
    final col = _dogsCol(userId);
    if (col == null) throw UnimplementedError('Firebase non configuré : ajoutez google-services.json');
    final ref = col.doc();
    final now = FieldValue.serverTimestamp();
    final payload = {
      ...data,
      'createdAt': now,
      'updatedAt': now,
    };
    await ref.set(payload);
    final doc = await ref.get();
    return DogModel.fromFirestore(doc);
  }

  Future<DogModel> updateDog(String userId, String dogId, Map<String, dynamic> data) async {
    final col = _dogsCol(userId);
    if (col == null) throw UnimplementedError('Firebase non configuré');
    final ref = col.doc(dogId);
    await ref.update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    final doc = await ref.get();
    return DogModel.fromFirestore(doc);
  }

  Future<void> deleteDog(String userId, String dogId) async {
    final col = _dogsCol(userId);
    if (col == null) return;
    await col.doc(dogId).delete();
  }
}
