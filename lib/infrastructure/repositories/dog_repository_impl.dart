import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/dog.dart';
import '../../domain/enums/user_dog_role.dart';
import '../../domain/interfaces/repositories/i_auth_repository.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';
import '../datasources/remote/dog_remote_datasource.dart';

/// Implémentation chien : Firestore users/{userId}/dogs. UserId depuis auth (Firebase ou REST).
class DogRepositoryImpl implements IDogRepository {
  DogRepositoryImpl(this._remote, this._authRepo);
  final DogRemoteDatasource _remote;
  final IAuthRepository _authRepo;

  Future<String> get _userId async => (await _authRepo.getCurrentUser())?.id ?? '';

  @override
  Future<List<Dog>> getDogs() async {
    final uid = await _userId;
    final list = await _remote.getDogs(uid);
    return list.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Dog?> getDogById(String dogId) async {
    final uid = await _userId;
    final m = await _remote.getDogById(uid, dogId);
    return m?.toEntity();
  }

  @override
  Future<Dog> createDog(CreateDogParams params) async {
    final uid = await _userId;
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
    final m = await _remote.createDog(uid, data);
    return m.toEntity();
  }

  @override
  Future<Dog> updateDog(String dogId, UpdateDogParams params) async {
    final uid = await _userId;
    final data = <String, dynamic>{};
    if (params.name != null) data['name'] = params.name;
    if (params.weight != null) data['weight'] = params.weight;
    if (params.photoUrl != null) data['photoUrl'] = params.photoUrl;
    final m = await _remote.updateDog(uid, dogId, data);
    return m.toEntity();
  }

  @override
  Future<void> deleteDog(String dogId) async {
    final uid = await _userId;
    return _remote.deleteDog(uid, dogId);
  }

  @override
  Future<List<UserDogAccess>> getDogUsers(String dogId) async => [];

  @override
  Future<void> inviteUser(String dogId, {required String email, required UserDogRole role}) async {}

  @override
  Future<void> removeUser(String dogId, String userId) async {}
}
