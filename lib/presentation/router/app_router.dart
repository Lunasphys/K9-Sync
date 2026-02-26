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
import '../screens/auth/welcome_login_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/map/trail_history_screen.dart';
import '../screens/map/trail_detail_screen.dart';
import '../screens/map/lost_mode_screen.dart';
import '../screens/health/health_dashboard_screen.dart';
import '../screens/health/activity_screen.dart';
import '../screens/health/sleep_screen.dart';
import '../screens/health/anomaly_screen.dart';
import '../screens/dog/dog_list_screen.dart';
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

/// Configuration Go Router : routes, redirect auth, StatefulShellRoute pour la bottom nav.
GoRouter createAppRouter({bool Function()? isLoggedIn}) {
  final loggedIn = isLoggedIn ?? () => false;
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final path = state.matchedLocation;
      return authGuard(loggedIn(), path);
    },
    routes: [
      // Auth & onboarding
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.consent, builder: (context, state) => const ConsentScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const WelcomeLoginScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),

      // Zone connectée : shell avec 5 onglets (Go Router StatefulShellRoute)
      GoRoute(
        path: AppRoutes.home,
        redirect: (context, state) {
          final loc = state.matchedLocation;
          if (loc == AppRoutes.home || loc == '${AppRoutes.home}/') {
            return AppRoutes.homeAccueil;
          }
          return null;
        },
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(path: 'accueil', builder: (context, state) => const ConnectedHomeScreen()),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: 'carte', builder: (context, state) => const MapScreen()),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: 'alertes', builder: (context, state) => const AlertsScreen()),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: 'sante', builder: (context, state) => const HealthDashboardScreen()),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'profil',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Routes plein écran (hors shell)
      GoRoute(path: AppRoutes.pairing, builder: (context, state) => const PairingScreen()),
      GoRoute(path: AppRoutes.map, builder: (context, state) => const MapScreen()),
      GoRoute(
        path: AppRoutes.trailHistory,
        builder: (context, state) => const TrailHistoryScreen(),
        routes: [
          GoRoute(
            path: 'detail',
            builder: (context, state) => const TrailDetailScreen(),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.lostMode, builder: (context, state) => const LostModeScreen()),
      GoRoute(path: AppRoutes.healthDashboard, builder: (context, state) => const HealthDashboardScreen()),
      GoRoute(path: AppRoutes.activity, builder: (context, state) => const ActivityScreen()),
      GoRoute(path: AppRoutes.sleep, builder: (context, state) => const SleepScreen()),
      GoRoute(path: AppRoutes.anomaly, builder: (context, state) => const AnomalyScreen()),
      GoRoute(path: AppRoutes.dogList, builder: (context, state) => const DogListScreen()),
      GoRoute(
        path: '/dogs/:dogId',
        builder: (context, state) {
          final dogId = state.pathParameters['dogId'];
          return DogProfileScreen(dogId: dogId);
        },
        routes: [
          GoRoute(
            path: 'shared-access',
            builder: (context, state) {
              final dogId = state.pathParameters['dogId'];
              return SharedAccessScreen(dogId: dogId);
            },
          ),
          GoRoute(
            path: 'invite',
            builder: (context, state) {
              final dogId = state.pathParameters['dogId'];
              return InviteUserScreen(dogId: dogId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/collar/:collarId',
        builder: (context, state) {
          final collarId = state.pathParameters['collarId'];
          return CollarStatusScreen(collarId: collarId);
        },
      ),
      GoRoute(path: AppRoutes.alertsList, builder: (context, state) => const AlertsListScreen()),
      GoRoute(path: AppRoutes.notificationSettings, builder: (context, state) => const NotificationSettingsScreen()),
      GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: AppRoutes.subscription, builder: (context, state) => const SubscriptionScreen()),
      GoRoute(path: AppRoutes.privacy, builder: (context, state) => const PrivacyScreen()),
      GoRoute(path: AppRoutes.vet, builder: (context, state) => const VetJournalScreen()),
      GoRoute(path: AppRoutes.community, builder: (context, state) => const CommunityScreen()),
    ],
  );
}
