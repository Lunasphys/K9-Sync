import '../../domain/interfaces/repositories/i_auth_repository.dart';

/// Refresh JWT use case.
class RefreshTokenUseCase {
  final IAuthRepository _repo;

  RefreshTokenUseCase(this._repo);

  Future<AuthResult> call() => _repo.refreshToken();
}
