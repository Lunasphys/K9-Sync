import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'injection.dart';
import 'domain/interfaces/repositories/i_auth_repository.dart';
import 'presentation/router/app_router.dart';

/// MaterialApp + GoRouter + Riverpod. [setupDependencies] après Firebase.initializeApp().
class K9SyncApp extends StatelessWidget {
  const K9SyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'K9 Sync',
        theme: AppTheme.light,
        routerConfig: createAppRouter(
          isLoggedIn: () => getIt<IAuthRepository>().isLoggedIn,
        ),
      ),
    );
  }
}
