import 'package:go_router/go_router.dart';

/// Centralized route path constants.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const consent = '/consent';
  static const login = '/login';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const dogSetup = '/dog-setup';
  static const forgotPassword = '/forgot-password';

  // Shell root (StatefulShellRoute branches)
  static const home = '/home';
  static const homeAccueil = '/home/accueil';
  static const homeCarte = '/home/carte';
  static const homeAlertes = '/home/alertes';
  static const homeSante = '/home/sante';
  static const homeProfil = '/home/profil';

  // Full-screen routes
  static const pairing = '/pairing';
  static const map = '/map';
  static const trailHistory = '/trail-history';
  static const lostMode = '/lost-mode';
  static const healthDashboard = '/health';
  static const activity = '/health/activity';
  static const sleep = '/health/sleep';
  static const anomaly = '/health/anomaly';
  static const dogList = '/dogs';
  static const alertsList = '/alerts';
  static const notificationSettings = '/notification-settings';
  static const settings = '/settings';
  static const subscription = '/subscription';
  static const privacy = '/privacy';
  static const vet = '/vet';
  static const community = '/community';
}

/// Auth guard — called by GoRouter redirect.
/// Returns a redirect path or null (= stay on current route).
String? authGuard(bool isLoggedIn, String currentPath) {
  const publicRoutes = {
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.consent,
    AppRoutes.login,
    AppRoutes.signIn,
    AppRoutes.register,
    AppRoutes.forgotPassword,
  };

  final isPublic = publicRoutes.contains(currentPath);

  if (!isLoggedIn && !isPublic) return AppRoutes.login;
  if (isLoggedIn && isPublic && currentPath != AppRoutes.splash) {
    return AppRoutes.homeAccueil;
  }
  return null;
}

