import '../../entities/dog.dart';
import '../../enums/user_dog_role.dart';

/// Contract for dog CRUD and sharing (Clean Architecture — domain).
abstract interface class IDogRepository {
  Future<List<Dog>> getDogs();
  Future<Dog?> getDogById(String dogId);
  Future<Dog> createDog(CreateDogParams params);
  Future<Dog> updateDog(String dogId, UpdateDogParams params);
  Future<void> deleteDog(String dogId);
  Future<List<UserDogAccess>> getDogUsers(String dogId);
  Future<void> inviteUser(String dogId, {required String email, required UserDogRole role});
  Future<void> removeUser(String dogId, String userId);
}

class CreateDogParams {
  final String name;
  final String? breed;
  final DateTime? birthDate;
  final double? weight;
  final DogSex? sex;
  final List<String> allergies;
  final List<String> characterTraits;
  final String? photoUrl;

  const CreateDogParams({
    required this.name,
    this.breed,
    this.birthDate,
    this.weight,
    this.sex,
    this.allergies = const [],
    this.characterTraits = const [],
    this.photoUrl,
  });
}

class UpdateDogParams {
  final String? name;
  final String? breed;
  final DateTime? birthDate;
  final double? weight;
  final String? sex;
  final List<String>? allergies;
  final String? photoUrl;

  const UpdateDogParams({
    this.name,
    this.breed,
    this.birthDate,
    this.weight,
    this.sex,
    this.allergies,
    this.photoUrl,
  });
}

class UserDogAccess {
  final String userId;
  final String dogId;
  final UserDogRole role;
  final bool canEdit;
  final DateTime? expiresAt;

  const UserDogAccess({
    required this.userId,
    required this.dogId,
    required this.role,
    this.canEdit = false,
    this.expiresAt,
  });
}
