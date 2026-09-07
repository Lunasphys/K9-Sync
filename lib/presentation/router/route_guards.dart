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

/// In-memory cache of the mandatory-consent check used by [authGuard].
/// `null` means "not checked yet this session" — once known, [authGuard]
/// reads this instead of hitting the network on every navigation.
///
/// This is the single source of truth for "has this session accepted the
/// mandatory consent" across every entry point (cold-start splash,
/// interactive login, a future deep link): none of them run their own
/// check anymore, they all resolve through [authGuard].
bool? _hasAcceptedConsentCache;

/// Call when the session ends (explicit logout, expired-token redirect)
/// so a new session on the same app instance gets a fresh check.
void resetConsentCache() => _hasAcceptedConsentCache = null;

/// Call right after [ConsentScreen] successfully submits, so the redirect
/// that follows doesn't re-fetch from the server to learn what it just
/// wrote.
void markConsentAccepted() => _hasAcceptedConsentCache = true;

/// Auth + consent guard — called by GoRouter redirect on every navigation.
/// Returns a redirect path or null (= stay on current route).
///
/// [AppRoutes.consent] is deliberately NOT in [publicRoutes]: it is only
/// ever reached by an already-logged-in user (post-login from splash, or
/// right after registration) who must review it before the rest of the
/// app. Treating it as "public" would bounce them straight back to
/// [AppRoutes.homeAccueil] via the isLoggedIn-on-a-public-route rule below,
/// defeating the whole point of the screen.
///
/// [hasAcceptedConsent] is only ever awaited once per session (see
/// [_hasAcceptedConsentCache]) — every navigation after that resolves
/// synchronously.
Future<String?> authGuard(
  bool isLoggedIn,
  String currentPath, {
  required Future<bool> Function() hasAcceptedConsent,
}) async {
  const publicRoutes = {
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.signIn,
    AppRoutes.register,
    AppRoutes.forgotPassword,
  };

  final isPublic = publicRoutes.contains(currentPath);

  if (!isLoggedIn) {
    resetConsentCache();
    return isPublic ? null : AppRoutes.login;
  }

  // Logged in. Every protected route — including a direct deep link — is
  // gated on the mandatory consent, except the consent screen itself.
  if (currentPath != AppRoutes.consent) {
    _hasAcceptedConsentCache ??= await hasAcceptedConsent();
    if (!_hasAcceptedConsentCache!) return AppRoutes.consent;
  }

  if (isPublic && currentPath != AppRoutes.splash) {
    return AppRoutes.homeAccueil;
  }
  return null;
}
