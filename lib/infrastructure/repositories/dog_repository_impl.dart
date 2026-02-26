import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/dog.dart';
import '../../domain/enums/user_dog_role.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';
import '../datasources/remote/dog_remote_datasource.dart';

/// Implémentation chien MVP : Firestore users/{userId}/dogs.
class DogRepositoryImpl implements IDogRepository {
  DogRepositoryImpl(this._remote, this._auth);
  final DogRemoteDatasource _remote;
  final FirebaseAuth _auth;

  String get _userId => _auth.currentUser?.uid ?? '';

  @override
  Future<List<Dog>> getDogs() async {
    final list = await _remote.getDogs(_userId);
    return list.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Dog?> getDogById(String dogId) async {
    final m = await _remote.getDogById(_userId, dogId);
    return m?.toEntity();
  }

  @override
  Future<Dog> createDog(CreateDogParams params) async {
    final data = {
      'name': params.name,
      'breed': params.breed,
      'birthDate': params.birthDate != null ? Timestamp.fromDate(params.birthDate!) : null,
      'weight': params.weight,
      'sex': params.sex?.name,
      'allergies': params.allergies,
      'characterTraits': params.characterTraits,
      'photoUrl': params.photoUrl,
    };
    final m = await _remote.createDog(_userId, data);
    return m.toEntity();
  }

  @override
  Future<Dog> updateDog(String dogId, UpdateDogParams params) async {
    final data = <String, dynamic>{};
    if (params.name != null) data['name'] = params.name;
    if (params.weight != null) data['weight'] = params.weight;
    if (params.photoUrl != null) data['photoUrl'] = params.photoUrl;
    final m = await _remote.updateDog(_userId, dogId, data);
    return m.toEntity();
  }

  @override
  Future<void> deleteDog(String dogId) async => _remote.deleteDog(_userId, dogId);

  @override
  Future<List<UserDogAccess>> getDogUsers(String dogId) async => [];

  @override
  Future<void> inviteUser(String dogId, {required String email, required UserDogRole role}) async {}

  @override
  Future<void> removeUser(String dogId, String userId) async {}
}
