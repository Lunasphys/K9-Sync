import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'injection.dart';
import 'domain/interfaces/repositories/i_auth_repository.dart';
import 'presentation/router/app_router.dart';
import 'presentation/router/route_guards.dart';

/// MaterialApp + GoRouter + Riverpod. [setupDependencies] après Firebase.initializeApp().
/// Écoute [sessionStream] pour rediriger vers /login quand le token expire (intercepteur 401).
class K9SyncApp extends StatefulWidget {
  const K9SyncApp({super.key});

  @override
  State<K9SyncApp> createState() => _K9SyncAppState();
}

class _K9SyncAppState extends State<K9SyncApp> {
  late final GoRouter _router;
  StreamSubscription<bool>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(
      isLoggedIn: () => getIt<IAuthRepository>().isLoggedIn,
    );
    _sessionSub = getIt<IAuthRepository>().sessionStream.listen((loggedIn) {
      if (!loggedIn && mounted) _router.go(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'K9 Sync',
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
