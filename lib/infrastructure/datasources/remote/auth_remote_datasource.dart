import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firebase_constants.dart';
import '../../../core/debug/debug_logger.dart';
import '../../../core/errors/auth_error.dart';
import '../../models/user_model.dart';

/// Datasource auth : Firebase (MVP) ou REST (backend).
abstract class AuthRemoteDatasource {
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });
  Future<AuthResponse> login({required String email, required String password});
  Future<void> logout();
  Future<void> forgotPassword({required String email});
  Future<UserModel?> getUserProfile(String uid);
  /// Profil courant (REST : GET /users/me ; Firebase : getUserProfile(uid)).
  Future<UserModel?> getMe();
  /// Refresh JWT (REST : POST /auth/refresh ; Firebase : getIdToken(true)).
  Future<AuthResponse> refreshToken();
}

class AuthResponse {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.accessToken,
    this.refreshToken = '',
  });
}

class AuthRemoteDatasourceFirebase implements AuthRemoteDatasource {
  AuthRemoteDatasourceFirebase(this._auth, this._firestore);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      final userModel = UserModel(
        id: uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: null,
        subscriptionPlan: 'free',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore.collection(FirebaseConstants.users).doc(uid).set({
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'subscriptionPlan': 'free',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final token = await cred.user!.getIdToken();
      DebugLogger.auth('Register OK uid=$uid');
      return AuthResponse(user: userModel, accessToken: token ?? '');
    } on FirebaseAuthException catch (e) {
      DebugLogger.auth('Register failed ${e.code}');
      throw AuthError.fromFirebase(e);
    }
  }

  @override
  Future<AuthResponse> login({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      final userDoc = await _firestore.collection(FirebaseConstants.users).doc(uid).get();
      if (!userDoc.exists) throw AuthError.invalidCredentials();
      final userModel = UserModel.fromFirestore(userDoc);
      final token = await cred.user!.getIdToken();
      DebugLogger.auth('Login OK uid=$uid');
      return AuthResponse(user: userModel, accessToken: token ?? '');
    } on FirebaseAuthException catch (e) {
      DebugLogger.auth('Login failed ${e.code}');
      throw AuthError.fromFirebase(e);
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    DebugLogger.auth('Logout');
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthError.fromFirebase(e);
    }
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection(FirebaseConstants.users).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  @override
  Future<UserModel?> getMe() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return getUserProfile(uid);
  }

  @override
  Future<AuthResponse> refreshToken() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthError.invalidCredentials();
    final token = await user.getIdToken(true);
    final model = await getUserProfile(user.uid);
    if (model == null) throw AuthError.invalidCredentials();
    return AuthResponse(user: model, accessToken: token ?? '', refreshToken: '');
  }
}
