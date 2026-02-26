import 'app_error.dart';

/// Network / API errors.
class NetworkError extends AppError {
  const NetworkError.noInternet()
      : super(
          code: 'NET_001',
          message: 'No internet connection',
          userMessage: 'Pas de connexion Internet.',
        );

  NetworkError.timeout({required String endpoint})
      : super(
          code: 'NET_002',
          message: 'Request timeout: $endpoint',
          userMessage: 'Le serveur met trop de temps à répondre.',
          context: {'endpoint': endpoint},
        );

  NetworkError.serverError({required int statusCode})
      : super(
          code: 'NET_003',
          message: 'Server error $statusCode',
          userMessage: 'Erreur serveur. Réessayez plus tard.',
          context: {'status': statusCode},
        );
}
