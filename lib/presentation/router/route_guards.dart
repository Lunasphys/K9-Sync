/// Route path constants (Go Router — single source of truth).
abstract final class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  /// Base de la zone connectée avec bottom nav (StatefulShellRoute).
  static const String home = '/home';
  static const String homeAccueil = '/home/accueil';
  static const String homeCarte = '/home/carte';
  static const String homeAlertes = '/home/alertes';
  static const String homeSante = '/home/sante';
  static const String homeProfil = '/home/profil';
  static const String homeChiens = '/home/chiens';

  static const String pairing = '/pairing';
  static const String map = '/map';
  static const String trailHistory = '/trail-history';
  static const String lostMode = '/lost-mode';
  static const String healthDashboard = '/health';
  static const String activity = '/activity';
  static const String sleep = '/sleep';
  static const String anomaly = '/anomaly';
  static const String dogList = '/dogs';
  static const String dogProfile = '/dogs/:dogId';
  static const String collarStatus = '/collar/:collarId';
  static const String alertsList = '/alerts';
  static const String notificationSettings = '/notification-settings';
  static const String settings = '/settings';
  static const String subscription = '/subscription';
  static const String privacy = '/privacy';
  static const String consent = '/consent';
  static const String signIn = '/sign-in';
  static const String vet = '/vet';
  static const String community = '/community';
}

/// Auth guard pour Go Router : retourne le chemin de redirection ou null.
String? authGuard(bool isLoggedIn, String location) {
  final publicPaths = [
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.signIn,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.onboarding,
    AppRoutes.consent,
  ];
  final isPublic = publicPaths.any((p) => location == p || (p.length > 1 && location.startsWith('$p/')));
  if (!isLoggedIn && !isPublic) {
    return AppRoutes.login;
  }
  if (isLoggedIn &&
      (location == AppRoutes.login ||
          location == AppRoutes.signIn ||
          location == AppRoutes.register ||
          location == AppRoutes.splash)) {
    return AppRoutes.homeAccueil;
  }
  return null;
}
