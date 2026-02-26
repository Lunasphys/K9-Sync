import '../../domain/interfaces/repositories/i_auth_repository.dart';

/// Login use case.
class LoginUseCase {
  final IAuthRepository _repo;

  LoginUseCase(this._repo);

  Future<AuthResult> call({required String email, required String password}) =>
      _repo.login(email: email, password: password);
}
