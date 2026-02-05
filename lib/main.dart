import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const K9SyncApp());
}

class K9SyncApp extends StatelessWidget {
  const K9SyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'K9 Sync',
      theme: AppTheme.light,
      routerConfig: createAppRouter(),
    );
  }
}
