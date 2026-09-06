import '../../domain/interfaces/repositories/i_auth_repository.dart';

/// Delete account use case (RGPD art. 17).
class DeleteAccountUseCase {
  final IAuthRepository _repo;

  DeleteAccountUseCase(this._repo);

  Future<void> call({required String password}) =>
      _repo.deleteAccount(password: password);
}
