import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';

/// Intercepteur Dio : injection du token (sauf /auth/*), sur 401 appel POST /auth/refresh puis retry.
class ApiInterceptor extends Interceptor {
  ApiInterceptor({
    required this.dio,
    required this.dioForRefresh,
    required this.getAccessToken,
    required this.getRefreshToken,
    required this.setTokens,
    required this.clearTokens,
  });

  final Dio dio;
  /// Dio sans intercepteur pour appeler POST /auth/refresh sans boucle 401.
  final Dio dioForRefresh;
  final Future<String?> Function() getAccessToken;
  final Future<String?> Function() getRefreshToken;
  final Future<void> Function({required String accessToken, required String refreshToken}) setTokens;
  final Future<void> Function() clearTokens;

  static bool _isAuthPath(String path) {
    final p = path.contains('?') ? path.split('?').first : path;
    return p.endsWith(ApiConstants.authLogin) ||
        p.endsWith(ApiConstants.authRegister) ||
        p.endsWith(ApiConstants.authRefresh) ||
        p.endsWith(ApiConstants.authLogout) ||
        p.endsWith(ApiConstants.authForgotPassword);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_isAuthPath(options.path)) {
      return handler.next(options);
    }
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isAuthPath(err.requestOptions.path)) {
      return handler.next(err);
    }
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearTokens();
      return handler.next(err);
    }
    try {
      final response = await dioForRefresh.post<Map<String, dynamic>>(
        ApiConstants.authRefresh,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      if (access != null && refresh != null) {
        await setTokens(accessToken: access, refreshToken: refresh);
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $access';
        final retry = await dio.fetch(opts);
        return handler.resolve(retry);
      }
    } catch (_) {
      await clearTokens();
    }
    handler.next(err);
  }
}
