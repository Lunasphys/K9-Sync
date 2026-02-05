import 'package:go_router/go_router.dart';

import 'package:k9sync/features/shell/presentation/pages/main_shell.dart';
import 'package:k9sync/features/pairing/presentation/pages/pairing_screen.dart';

/// Route path constants for navigation.
abstract final class AppRoutes {
  static const String home = '/';
  static const String pairing = '/pairing';
}

/// App router configuration (go_router).
/// To add a new page: add a path in [AppRoutes], then a [GoRoute] with path and builder.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: AppRoutes.pairing,
        builder: (context, state) => const PairingScreen(),
      ),
    ],
  );
}
