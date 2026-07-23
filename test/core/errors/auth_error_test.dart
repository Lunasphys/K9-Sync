import 'package:flutter_test/flutter_test.dart';
import 'package:k9sync/core/errors/auth_error.dart';

void main() {
  group('AppError.toString', () {
    test('formats as [code] message with context', () {
      final err = AuthError.insufficientPermissions(action: 'delete_dog');
      expect(err.toString(), '[AUTH_005] Permission denied: delete_dog {action: delete_dog}');
    });

    test('leaves a trailing blank when there is no context (context ?? \'\')', () {
      const err = AuthError.invalidCredentials();
      expect(err.toString(), '[AUTH_003] Invalid credentials ');
    });
  });

  group('AuthError named constructors', () {
    test('tokenExpired carries no user-facing message', () {
      const err = AuthError.tokenExpired();
      expect(err.code, 'AUTH_001');
      expect(err.userMessage, isNull);
    });

    test('invalidCredentials has a French user-facing message', () {
      const err = AuthError.invalidCredentials();
      expect(err.code, 'AUTH_003');
      expect(err.userMessage, 'Email ou mot de passe incorrect.');
    });

    test('insufficientPermissions records the denied action in context', () {
      final err = AuthError.insufficientPermissions(action: 'delete_dog');
      expect(err.code, 'AUTH_005');
      expect(err.context, {'action': 'delete_dog'});
      expect(err.message, contains('delete_dog'));
    });
  });

  group('AuthError.fromDio', () {
    test('maps a 401 status to AUTH_001', () {
      final err = AuthError.fromDio(Exception('DioException [bad response]: 401 Unauthorized'));
      expect(err.code, 'AUTH_001');
    });

    test('maps the word "Unauthorized" without a numeric code to AUTH_001', () {
      final err = AuthError.fromDio(Exception('Unauthorized access'));
      expect(err.code, 'AUTH_001');
    });

    test('maps a 403 status to AUTH_005', () {
      final err = AuthError.fromDio(Exception('Response status code 403'));
      expect(err.code, 'AUTH_005');
    });

    test('maps a 404 status to AUTH_003', () {
      final err = AuthError.fromDio(Exception('Response status code 404'));
      expect(err.code, 'AUTH_003');
    });

    test('an unrecognized error falls back to AUTH_000', () {
      final err = AuthError.fromDio(Exception('Connection reset by peer'));
      expect(err.code, 'AUTH_000');
    });

    test('checks 401 before 403/404 when a message could ambiguously match', () {
      // A message containing both "401" and "404" — 401 must win since it's checked first.
      final err = AuthError.fromDio(Exception('401 then retried and got 404'));
      expect(err.code, 'AUTH_001');
    });

    test('carries the original exception as cause', () {
      final original = Exception('401 Unauthorized');
      final err = AuthError.fromDio(original);
      expect(err.cause, same(original));
    });
  });

  group('AuthError.fromFirebase', () {
    test('maps user-not-found to AUTH_003', () {
      final err = AuthError.fromFirebase(Exception('user-not-found'));
      expect(err.code, 'AUTH_003');
      expect(err.userMessage, 'Email ou mot de passe incorrect.');
    });

    test('maps wrong-password to AUTH_003', () {
      final err = AuthError.fromFirebase(Exception('wrong-password'));
      expect(err.code, 'AUTH_003');
    });

    test('maps invalid-credential to AUTH_003', () {
      final err = AuthError.fromFirebase(Exception('invalid-credential'));
      expect(err.code, 'AUTH_003');
    });

    test('maps email-already-in-use to AUTH_004', () {
      final err = AuthError.fromFirebase(Exception('email-already-in-use'));
      expect(err.code, 'AUTH_004');
      expect(err.userMessage, 'Cet email est déjà utilisé.');
    });

    test('maps weak-password to AUTH_006', () {
      final err = AuthError.fromFirebase(Exception('weak-password'));
      expect(err.code, 'AUTH_006');
      expect(err.userMessage, 'Mot de passe trop faible.');
    });

    test('an unrecognized Firebase error falls back to AUTH_000 with a generic message', () {
      final err = AuthError.fromFirebase(Exception('network-request-failed'));
      expect(err.code, 'AUTH_000');
      expect(err.userMessage, "Erreur d'authentification. Réessayez.");
    });
  });
}
