import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import 'api_interceptor.dart';
import '../storage/secure_storage.dart';

/// Client HTTP partagé : baseUrl, timeouts, [ApiInterceptor] pour token + refresh 401.
class DioClient {
  DioClient({
    required SecureStorage secureStorage,
    String baseUrl = ApiConstants.baseUrl,
    int connectTimeoutMs = ApiConstants.timeoutMs,
    int receiveTimeoutMs = ApiConstants.timeoutMs,
    void Function()? onSessionExpired,
  }) : _baseUrl = baseUrl {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(milliseconds: connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: receiveTimeoutMs),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dioPlain = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(milliseconds: connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: receiveTimeoutMs),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    final interceptor = ApiInterceptor(
      dio: _dio,
      dioForRefresh: _dioPlain,
      getAccessToken: secureStorage.getAccessToken,
      getRefreshToken: secureStorage.getRefreshToken,
      setTokens: secureStorage.setTokens,
      clearTokens: secureStorage.clear,
      onSessionExpired: onSessionExpired,
    );
    _dio.interceptors.add(interceptor);
  }

  final String _baseUrl;
  late final Dio _dio;
  late final Dio _dioPlain;

  Dio get dio => _dio;
  Dio get dioPlain => _dioPlain;
  String get baseUrl => _baseUrl;
}
