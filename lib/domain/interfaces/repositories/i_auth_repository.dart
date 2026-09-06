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

  /// RGPD art. 20 — export complet des données de l'utilisateur authentifié
  /// (profil, chiens possédés, GPS, santé, activité, alertes, accès partagés).
  Future<Map<String, dynamic>> exportMyData();

  /// RGPD art. 17 — suppression définitive du compte. Requiert le mot de
  /// passe actuel ; lève [AuthError.invalidCredentials] s'il est incorrect,
  /// auquel cas rien n'est supprimé côté serveur.
  Future<void> deleteAccount({required String password});

  /// Vérifie le stockage (token) de façon asynchrone. À appeler au démarrage pour que [isLoggedIn] reflète l’état réel (REST).
  Future<void> ensureAuthChecked();
  bool get isLoggedIn;

  /// For API interceptor (current JWT). Null if not logged in.
  String? get accessToken;

  /// Stream émis lorsque la session devient invalide (ex. après clearTokens dans l'intercepteur).
  /// Écouter dans l'app pour rediriger vers /login.
  Stream<bool> get sessionStream;

  /// Marque la session comme expirée (isLoggedIn → false) et émet false sur [sessionStream].
  void invalidateSession();
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
