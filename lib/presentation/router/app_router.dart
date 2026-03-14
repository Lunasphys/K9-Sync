import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'route_guards.dart';
import '../../features/shell/presentation/pages/main_shell.dart';
import '../../features/pairing/presentation/pages/pairing_screen.dart';
import '../../features/welcome/presentation/pages/connected_home_screen.dart';
import '../../features/alerts/presentation/pages/alerts_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/onboarding/dog_setup_screen.dart';
import '../screens/auth/welcome_login_screen.dart';
import '../screens/map/map_screen.dart';
import 'package:k9sync/presentation/screens/map/trail_history_screen.dart';
import '../screens/map/trail_detail_screen.dart';
import '../screens/map/lost_mode_screen.dart';
import '../screens/health/health_dashboard_screen.dart';
import '../screens/health/activity_screen.dart';
import '../screens/health/sleep_screen.dart';
import '../screens/health/anomaly_screen.dart';
import '../screens/dog/dog_list_screen.dart';
import '../screens/dog/dog_edit_screen.dart';
import '../screens/dog/dog_profile_screen.dart';
import '../screens/dog/shared_access_screen.dart';
import '../screens/dog/invite_user_screen.dart';
import '../screens/dog/collar_status_screen.dart';
import '../screens/alerts/alerts_list_screen.dart';
import '../screens/alerts/notification_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/subscription_screen.dart';
import '../screens/privacy/privacy_screen.dart';
import '../screens/privacy/consent_screen.dart';
import '../screens/vet/vet_journal_screen.dart';
import '../screens/community/community_screen.dart';

/// App router. Pass [isLoggedIn] and [sessionExpiredNotifier] from injection.
///
/// When [sessionExpiredNotifier] fires (token refresh failed in ApiInterceptor),
/// GoRouter re-runs [redirect] via [refreshListenable]. Since isLoggedIn is
/// now false (tokens cleared), authGuard redirects to /login automatically —
/// no manual context.go() needed anywhere.
GoRouter createAppRouter({
  bool Function()? isLoggedIn,
  Listenable? sessionExpiredNotifier,
}) {
  final loggedIn = isLoggedIn ?? () => false;

  return GoRouter(
    initialLocation: AppRoutes.splash,
    // Re-evaluate redirect whenever the notifier fires (session expired)
    refreshListenable: sessionExpiredNotifier,
    redirect: (context, state) {
      final path = state.matchedLocation;

      // Redirect bare /home to the default tab
      if (path == AppRoutes.home || path == '${AppRoutes.home}/') {
        return AppRoutes.homeAccueil;
      }

      return authGuard(loggedIn(), path);
    },
    routes: [
      // ── Auth & onboarding ───────────────────────────────────────────
      GoRoute(path: AppRoutes.splash, builder: (c, s) => const SplashScreen()),
      GoRoute(path: AppRoutes.onboarding, builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.consent, builder: (c, s) => const ConsentScreen()),
      GoRoute(path: AppRoutes.login, builder: (c, s) => const WelcomeLoginScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (c, s) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (c, s) => const RegisterScreen()),
      GoRoute(path: AppRoutes.dogSetup, builder: (c, s) => const DogSetupScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (c, s) => const ForgotPasswordScreen()),

      // ── Main shell — 5-tab bottom nav ──────────────────────────────
      // StatefulShellRoute must be a direct child of the root routes list.
      // Wrapping it in a GoRoute('/home') causes goBranch to silently fail.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.homeAccueil,
                builder: (c, s) => const ConnectedHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.homeCarte,
                builder: (c, s) => const MapScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (c, s) => const TrailHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.homeAlertes,
                builder: (c, s) => const AlertsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.homeSante,
                builder: (c, s) => const HealthDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.homeProfil,
                builder: (c, s) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (outside shell) ─────────────────────────
      GoRoute(path: AppRoutes.pairing, builder: (c, s) => const PairingScreen()),
      GoRoute(path: AppRoutes.map, builder: (c, s) => const MapScreen()),
      GoRoute(
        path: AppRoutes.trailHistory,
        builder: (c, s) => const TrailHistoryScreen(),
        routes: [
          GoRoute(
            path: 'detail',
            builder: (c, s) => const TrailDetailScreen(),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.lostMode, builder: (c, s) => const LostModeScreen()),
      GoRoute(path: AppRoutes.healthDashboard, builder: (c, s) => const HealthDashboardScreen()),
      GoRoute(path: AppRoutes.activity, builder: (c, s) => const ActivityScreen()),
      GoRoute(path: AppRoutes.sleep, builder: (c, s) => const SleepScreen()),
      GoRoute(path: AppRoutes.anomaly, builder: (c, s) => const AnomalyScreen()),
      GoRoute(path: AppRoutes.dogList, builder: (c, s) => const DogListScreen()),
      GoRoute(
        path: '/dogs/:dogId',
        builder: (c, s) => DogProfileScreen(dogId: s.pathParameters['dogId']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (c, s) => DogEditScreen(dogId: s.pathParameters['dogId']!),
          ),
          GoRoute(
            path: 'shared-access',
            builder: (c, s) => SharedAccessScreen(dogId: s.pathParameters['dogId']!),
          ),
          GoRoute(
            path: 'invite',
            builder: (c, s) => InviteUserScreen(dogId: s.pathParameters['dogId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/collar/:collarId',
        builder: (c, s) => CollarStatusScreen(collarId: s.pathParameters['collarId']!),
      ),
      GoRoute(path: AppRoutes.alertsList, builder: (c, s) => const AlertsListScreen()),
      GoRoute(path: AppRoutes.notificationSettings, builder: (c, s) => const NotificationSettingsScreen()),
      GoRoute(path: AppRoutes.settings, builder: (c, s) => const SettingsScreen()),
      GoRoute(path: AppRoutes.subscription, builder: (c, s) => const SubscriptionScreen()),
      GoRoute(path: AppRoutes.privacy, builder: (c, s) => const PrivacyScreen()),
      GoRoute(path: AppRoutes.vet, builder: (c, s) => const VetJournalScreen()),
      GoRoute(path: AppRoutes.community, builder: (c, s) => const CommunityScreen()),
    ],
  );
}

