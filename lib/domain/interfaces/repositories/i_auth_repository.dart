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

  /// RGPD — enregistre un ou plusieurs consentements pour l'utilisateur
  /// authentifié (append-only côté serveur, chaque appel crée une nouvelle
  /// entrée d'historique).
  Future<void> submitConsents(List<ConsentSubmission> consents);

  /// RGPD — état actuel de chaque type de consentement (le plus récent
  /// enregistré), par type. Un type jamais soumis est absent de la map.
  Future<Map<String, bool>> getConsentStatus();

  /// Enregistre le token FCM de l'appareil courant pour l'utilisateur
  /// authentifié (un seul token par compte — le dernier appareil connecté
  /// gagne). À appeler à la connexion.
  Future<void> registerPushToken(String token);

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

/// One consent entry to submit — [type] matches [ConsentType.value] strings
/// ('terms_of_service', 'gps_data_collection', 'health_data_collection').
class ConsentSubmission {
  final String type;
  final bool accepted;
  final String version;

  const ConsentSubmission({
    required this.type,
    required this.accepted,
    required this.version,
  });
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
