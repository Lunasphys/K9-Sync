import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/debug/debug_logger.dart';
import '../../../core/errors/auth_error.dart';
import '../../models/user_model.dart';
import '../../network/dio_client.dart';
import '../../storage/secure_storage.dart';
import 'auth_remote_datasource.dart';

/// Datasource auth REST : backend /v1/auth/*, tokens dans [SecureStorage].
class AuthRemoteDatasourceRest implements AuthRemoteDatasource {
  AuthRemoteDatasourceRest(this._dioClient, this._storage);
  final DioClient _dioClient;
  final SecureStorage _storage;

  @override
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final res = await _dioClient.dio.post<Map<String, dynamic>>(
        ApiConstants.authRegister,
        data: {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
        },
      );
      final r = _parseAuthResponse(res.data);
      await _storage.setTokens(accessToken: r.accessToken, refreshToken: r.refreshToken);
      DebugLogger.auth('Register OK id=${r.user.id}');
      return r;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> login({required String email, required String password}) async {
    try {
      final res = await _dioClient.dio.post<Map<String, dynamic>>(
        ApiConstants.authLogin,
        data: {'email': email, 'password': password},
      );
      final r = _parseAuthResponse(res.data);
      await _storage.setTokens(accessToken: r.accessToken, refreshToken: r.refreshToken);
      DebugLogger.auth('Login OK id=${r.user.id}');
      return r;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  AuthResponse _parseAuthResponse(Map<String, dynamic>? data) {
    if (data == null) throw AuthError.invalidCredentials();
    final userJson = data['user'] as Map<String, dynamic>?;
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (userJson == null || access == null || refresh == null) {
      throw AuthError.invalidCredentials();
    }
    final user = UserModel.fromJson(userJson);
    return AuthResponse(user: user, accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> logout() async {
    try {
      await _dioClient.dio.post(ApiConstants.authLogout);
    } catch (_) {}
    await _storage.clear();
    DebugLogger.auth('Logout');
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      await _dioClient.dio.post(
        ApiConstants.authForgotPassword,
        data: {'email': email},
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    return getMe();
  }

  @override
  Future<UserModel?> getMe() async {
    try {
      final res = await _dioClient.dio.get<Map<String, dynamic>>(ApiConstants.userMe);
      final data = res.data;
      if (data == null) return null;
      final userJson = data['user'] as Map<String, dynamic>? ?? data;
      return UserModel.fromJson(Map<String, dynamic>.from(userJson));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      _handleDioError(e);
    }
  }

  @override
  Future<AuthResponse> refreshToken() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) throw AuthError.tokenExpired();
    try {
      final res = await _dioClient.dioPlain.post<Map<String, dynamic>>(
        ApiConstants.authRefresh,
        data: {'refreshToken': refresh},
      );
      final r = _parseAuthResponse(res.data);
      await _storage.setTokens(accessToken: r.accessToken, refreshToken: r.refreshToken);
      return r;
    } on DioException catch (e) {
      await _storage.clear();
      _handleDioError(e);
    }
  }

  Never _handleDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) throw AuthError.tokenExpired();
    if (status == 403) throw AuthError.insufficientPermissions(action: 'auth');
    throw AuthError.fromDio(e);
  }
}
