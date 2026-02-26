import 'package:firebase_auth/firebase_auth.dart' hide User;

import '../../domain/entities/user.dart';
import '../../domain/interfaces/repositories/i_auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';

/// Implémentation auth MVP : Firebase Auth + Firestore (pas de Dio).
class AuthRepositoryImpl implements IAuthRepository {
  AuthRepositoryImpl(this._remote, this._auth);
  final AuthRemoteDatasource _remote;
  final FirebaseAuth _auth;

  @override
  bool get isLoggedIn => _auth.currentUser != null;

  @override
  String? get accessToken => null;

  @override
  Future<User?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final model = await _remote.getUserProfile(uid);
    return model?.toEntity();
  }

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    final res = await _remote.login(email: email, password: password);
    return AuthResult(
      user: res.user.toEntity(),
      accessToken: res.accessToken,
      refreshToken: '',
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
    return AuthResult(
      user: res.user.toEntity(),
      accessToken: res.accessToken,
      refreshToken: '',
    );
  }

  @override
  Future<AuthResult> refreshToken() async {
    final user = await getCurrentUser();
    if (user == null) throw StateError('Not logged in');
    final token = await _auth.currentUser?.getIdToken(true);
    return AuthResult(user: user, accessToken: token ?? '', refreshToken: '');
  }

  @override
  Future<void> logout() async => _remote.logout();

  @override
  Future<void> forgotPassword({required String email}) async => _remote.forgotPassword(email: email);
}
