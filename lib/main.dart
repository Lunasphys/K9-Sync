import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'domain/interfaces/repositories/i_auth_repository.dart';
import 'injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local persistence (trails, etc.)
  await Hive.initFlutter();

  bool firebaseAvailable = false;
  try {
    await Firebase.initializeApp();
    firebaseAvailable = true;
  } on PlatformException catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase non initialisé (config absente): ${e.message}');
    }
  } on Exception catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase non initialisé: $e');
    }
  }

  setupDependencies(firebaseAvailable: firebaseAvailable);
  // Force la résolution du repo auth pour éviter « IAuthRepository is not registered » au premier accès (Splash).
  getIt<IAuthRepository>();
  runApp(const K9SyncApp());
}
