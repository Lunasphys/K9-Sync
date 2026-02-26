import '../../entities/user.dart';

/// Contract for authentication (Clean Architecture — domain).
abstract interface class IAuthRepository {
  Future<AuthResult> login({required String email, required String password});
  Future<AuthResult> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });
  Future<AuthResult> refreshToken();
  Future<void> logout();
  Future<void> forgotPassword({required String email});
  Future<User?> getCurrentUser();
  /// Vérifie le stockage (token) de façon asynchrone. À appeler au démarrage pour que [isLoggedIn] reflète l’état réel (REST).
  Future<void> ensureAuthChecked();
  bool get isLoggedIn;
  /// For API interceptor (current JWT). Null if not logged in.
  String? get accessToken;
}

/// Result of login/register/refresh.
class AuthResult {
  final User user;
  final String accessToken;
  final String refreshToken;

  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });
}
