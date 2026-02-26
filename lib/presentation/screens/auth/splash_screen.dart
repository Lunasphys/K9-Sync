import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Splash: vérifie le token (REST) puis redirige vers login ou home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuthAndNavigate());
  }

  Future<void> _checkAuthAndNavigate() async {
    final repo = getIt.isRegistered<IAuthRepository>() ? getIt<IAuthRepository>() : null;
    if (repo == null) {
      if (!mounted) return;
      context.go(AppRoutes.login);
      return;
    }
    await repo.ensureAuthChecked();
    if (!mounted) return;
    if (repo.isLoggedIn) {
      context.go(AppRoutes.homeAccueil);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80),
            SizedBox(height: 16),
            Text('K9 Sync', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
