import 'package:dio/dio.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/auth_error.dart';
import '../../core/errors/business_error.dart';
import '../../core/errors/network_error.dart';

/// Convertit une [DioException] en [AppError] métier.
/// À utiliser dans le catch de chaque repository.
AppError defaultMap(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
      return const NetworkError.noInternet();
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
      return NetworkError.timeout(endpoint: e.requestOptions.path);
    case DioExceptionType.cancel:
      return const NetworkError.cancelled();
    default:
      break;
  }

  final status = e.response?.statusCode ?? 0;
  final code = e.response?.data?['error']?['code'] as String?;
  final msg = e.response?.data?['error']?['message'] as String?;

  switch (status) {
    case 400:
      return BusinessError.validationFailed(
        message: msg ?? 'Requête invalide',
      );
    case 401:
      return const AuthError.tokenExpired();
    case 403:
      return AuthError.insufficientPermissions(
        action: code ?? e.requestOptions.path,
      );
    case 404:
      return NetworkError.notFound(path: e.requestOptions.path);
    case 429:
      return const NetworkError.rateLimited();
    case 422:
      return BusinessError.validationFailed(
        message: msg ?? 'Données invalides',
      );
    default:
      return NetworkError.serverError(statusCode: status);
  }
}
