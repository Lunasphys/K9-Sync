import 'app_error.dart';

/// Authentication errors. Utiliser [AuthError.fromFirebase] pour wrapper les exceptions Firebase.
class AuthError extends AppError {
  const AuthError.tokenExpired()
      : super(
          code: 'AUTH_001',
          message: 'JWT token expired',
          userMessage: null,
        );

  const AuthError.invalidCredentials()
      : super(
          code: 'AUTH_003',
          message: 'Invalid credentials',
          userMessage: 'Email ou mot de passe incorrect.',
        );

  AuthError.insufficientPermissions({required String action})
      : super(
          code: 'AUTH_005',
          message: 'Permission denied: $action',
          userMessage: "Vous n'avez pas les droits pour cette action.",
          context: {'action': action},
        );

  /// Wrapper pour DioException (REST backend).
  factory AuthError.fromDio(Object e) {
    final code = _dioCode(e);
    final message = e.toString();
    final userMessage = _userMessage(code);
    return AuthError._(
      code: code,
      message: message,
      userMessage: userMessage,
      cause: e,
    );
  }

  static String _dioCode(Object e) {
    final s = e.toString();
    if (s.contains('401') || s.contains('Unauthorized')) return 'AUTH_001';
    if (s.contains('403')) return 'AUTH_005';
    if (s.contains('404')) return 'AUTH_003';
    return 'AUTH_000';
  }

  /// Wrapper pour FirebaseAuthException (MVP Firebase).
  factory AuthError.fromFirebase(Object e) {
    final code = _firebaseCode(e);
    final message = e.toString();
    final userMessage = _userMessage(code);
    return AuthError._(
      code: code,
      message: message,
      userMessage: userMessage,
      cause: e,
    );
  }

  AuthError._({
    required super.code,
    required super.message,
    required super.userMessage,
    super.cause,
    Map<String, dynamic>? context,
  }) : super(context: context);

  static String _firebaseCode(Object e) {
    final s = e.toString();
    if (s.contains('user-not-found') || s.contains('wrong-password') || s.contains('invalid-credential')) {
      return 'AUTH_003';
    }
    if (s.contains('email-already-in-use')) return 'AUTH_004';
    if (s.contains('weak-password')) return 'AUTH_006';
    return 'AUTH_000';
  }

  static String? _userMessage(String code) {
    switch (code) {
      case 'AUTH_003':
        return 'Email ou mot de passe incorrect.';
      case 'AUTH_004':
        return 'Cet email est déjà utilisé.';
      case 'AUTH_006':
        return 'Mot de passe trop faible.';
      default:
        return 'Erreur d\'authentification. Réessayez.';
    }
  }
}
