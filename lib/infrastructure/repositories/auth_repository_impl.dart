import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;

import '../../core/constants/api_constants.dart';
import '../../core/errors/auth_error.dart';
import '../../domain/entities/user.dart';
import '../../domain/interfaces/repositories/i_auth_repository.dart';
import '../../injection.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../storage/secure_storage.dart';

/// Implémentation auth : Firebase (auth != null) ou REST (secureStorage != null).
class AuthRepositoryImpl implements IAuthRepository {
  AuthRepositoryImpl(
    this._remote, [
    FirebaseAuth? auth,
    SecureStorage? secureStorage,
  ]) : _auth = auth,
       _secureStorage = secureStorage,
       _sessionController = StreamController<bool>.broadcast() {
    assert(
      (auth != null) != (secureStorage != null),
      'Exactly one of auth (Firebase) or secureStorage (REST) must be provided.',
    );
  }

  final AuthRemoteDatasource _remote;
  final FirebaseAuth? _auth;
  final SecureStorage? _secureStorage;
  final StreamController<bool> _sessionController;

  bool get _isRest => _secureStorage != null;

  /// Cache pour REST : mis à jour par [ensureAuthChecked], [login], [logout] et [invalidateSession].
  bool _cachedLoggedIn = false;

  @override
  Stream<bool> get sessionStream => _sessionController.stream;

  @override
  void invalidateSession() {
    if (_isRest) _cachedLoggedIn = false;
    _sessionController.add(false);
  }

  @override
  bool get isLoggedIn {
    if (_isRest) return _cachedLoggedIn;
    return _auth!.currentUser != null;
  }

  @override
  Future<void> ensureAuthChecked() async {
    if (!_isRest) return;
    _cachedLoggedIn = (await _secureStorage!.getAccessToken()) != null;
  }

  @override
  String? get accessToken => null;

  @override
  Future<User?> getCurrentUser() async {
    if (_isRest) {
      final model = await _remote.getMe();
      return model?.toEntity();
    }
    final uid = _auth!.currentUser?.uid;
    if (uid == null) return null;
    final model = await _remote.getUserProfile(uid);
    return model?.toEntity();
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _remote.login(email: email, password: password);
    if (_isRest) _cachedLoggedIn = true;
    return AuthResult(
      user: res.user.toEntity(),
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
    );
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final res = await _remote.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    if (_isRest) _cachedLoggedIn = true;
    return AuthResult(
      user: res.user.toEntity(),
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
    );
  }

  @override
  Future<AuthResult> refreshToken() async {
    final res = await _remote.refreshToken();
    return AuthResult(
      user: res.user.toEntity(),
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
    );
  }

  @override
  Future<void> logout() async {
    await _remote.logout();
    if (_isRest) _cachedLoggedIn = false;
  }

  @override
  Future<void> forgotPassword({required String email}) async =>
      _remote.forgotPassword(email: email);

  @override
  Future<Map<String, dynamic>> exportMyData() async {
    if (!_isRest) {
      throw UnsupportedError('Data export is only available in REST mode.');
    }
    final response = await getIt<Dio>().get<Map<String, dynamic>>(
      ApiConstants.userExport,
    );
    return response.data ?? {};
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    if (!_isRest) {
      throw UnsupportedError('Account deletion is only available in REST mode.');
    }
    try {
      await getIt<Dio>().delete(
        ApiConstants.userMe,
        data: {'password': password},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw AuthError.invalidCredentials();
      rethrow;
    }
    await _secureStorage!.clear();
    _cachedLoggedIn = false;
  }

  @override
  Future<void> submitConsents(List<ConsentSubmission> consents) async {
    if (!_isRest) {
      throw UnsupportedError('Consents are only available in REST mode.');
    }
    await getIt<Dio>().post<void>(
      ApiConstants.userConsents,
      data: {
        'consents': consents
            .map(
              (c) => {
                'type': c.type,
                'accepted': c.accepted,
                'version': c.version,
              },
            )
            .toList(),
      },
    );
  }

  @override
  Future<Map<String, bool>> getConsentStatus() async {
    if (!_isRest) {
      throw UnsupportedError('Consents are only available in REST mode.');
    }
    final response = await getIt<Dio>().get<Map<String, dynamic>>(
      ApiConstants.userConsents,
    );
    final raw =
        (response.data?['consents'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    return raw.map(
      (type, value) =>
          MapEntry(type, (value as Map<String, dynamic>)['accepted'] as bool),
    );
  }

  @override
  Future<void> registerPushToken(String token) async {
    if (!_isRest) {
      throw UnsupportedError('Push token registration is only available in REST mode.');
    }
    await getIt<Dio>().post<void>(
      ApiConstants.userPushToken,
      data: {'token': token},
    );
  }
}
