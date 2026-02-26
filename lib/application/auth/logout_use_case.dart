import '../../domain/interfaces/repositories/i_auth_repository.dart';

/// Logout use case.
class LogoutUseCase {
  final IAuthRepository _repo;

  LogoutUseCase(this._repo);

  Future<void> call() => _repo.logout();
}
