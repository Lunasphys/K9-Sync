import '../../domain/entities/user.dart';
import '../../domain/interfaces/repositories/i_auth_repository.dart';

/// Récupère l'utilisateur connecté (ou null).
class GetCurrentUserUseCase {
  GetCurrentUserUseCase(this._repo);
  final IAuthRepository _repo;

  Future<User?> call() => _repo.getCurrentUser();
}
