import '../../domain/interfaces/repositories/i_auth_repository.dart';

/// Register use case.
class RegisterUseCase {
  final IAuthRepository _repo;

  RegisterUseCase(this._repo);

  Future<AuthResult> call({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) =>
      _repo.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
}
