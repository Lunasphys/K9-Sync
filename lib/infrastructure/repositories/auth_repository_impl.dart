import 'package:firebase_auth/firebase_auth.dart' hide User;

import '../../domain/entities/user.dart';
import '../../domain/interfaces/repositories/i_auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../storage/secure_storage.dart';

/// Implémentation auth : Firebase (auth != null) ou REST (secureStorage != null).
class AuthRepositoryImpl implements IAuthRepository {
  AuthRepositoryImpl(this._remote, [FirebaseAuth? auth, SecureStorage? secureStorage])
      : _auth = auth,
        _secureStorage = secureStorage {
    assert(
      (auth != null) != (secureStorage != null),
      'Exactly one of auth (Firebase) or secureStorage (REST) must be provided.',
    );
  }

  final AuthRemoteDatasource _remote;
  final FirebaseAuth? _auth;
  final SecureStorage? _secureStorage;

  bool get _isRest => _secureStorage != null;

  /// Cache pour REST : mis à jour par [ensureAuthChecked], [login] et [logout].
  bool _cachedLoggedIn = false;

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
  Future<AuthResult> login({required String email, required String password}) async {
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
  Future<void> forgotPassword({required String email}) async => _remote.forgotPassword(email: email);
}
