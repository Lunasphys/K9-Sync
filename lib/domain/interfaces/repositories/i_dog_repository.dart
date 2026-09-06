import '../../entities/collar.dart';
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

  /// Invite a user to share access to [dogId]. [expiresAt] is required when
  /// [role] is [UserDogRole.dogSitter]. Returns whether access was granted
  /// immediately (the email already has an account) or is pending (deferred
  /// until that email registers) — never throws for the "pending" case,
  /// that is a normal, successful outcome.
  Future<InviteOutcome> inviteUser(
    String dogId, {
    required String email,
    required UserDogRole role,
    DateTime? expiresAt,
  });
  Future<void> removeUser(String dogId, String userId);

  /// Pair a collar to [dogId] by its serial number (manual entry, no BLE
  /// scan). Provisions the collar if the serial is unknown, claims it if it
  /// exists but is unpaired, or succeeds idempotently if already paired to
  /// this exact dog. Throws (409 mapped) if the serial belongs to another
  /// dog, or if this dog already has a different collar paired.
  Future<Collar> pairCollar(String dogId, {required String serialNumber});
}

enum InviteOutcome {
  /// The invited email already had an account — access was granted right away.
  granted,

  /// The invited email has no account yet — access will be granted
  /// automatically once someone registers with that exact email.
  pending,
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
  final String email;
  final String firstName;
  final String lastName;
  final UserDogRole role;
  final bool canEdit;
  final DateTime? expiresAt;

  const UserDogAccess({
    required this.userId,
    required this.dogId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.canEdit = false,
    this.expiresAt,
  });
}
