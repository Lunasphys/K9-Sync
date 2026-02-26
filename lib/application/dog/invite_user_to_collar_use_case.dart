import '../../domain/enums/user_dog_role.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';

/// Invite user to dog/collar use case.
class InviteUserToCollarUseCase {
  final IDogRepository _repo;

  InviteUserToCollarUseCase(this._repo);

  Future<void> call(String dogId, {required String email, required UserDogRole role}) =>
      _repo.inviteUser(dogId, email: email, role: role);
}
