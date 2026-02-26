/// API base URL and endpoint paths. Prefer reading from env (API_BASE_URL) at runtime.
abstract final class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.k9sync.app/v1',
  );
  static const int timeoutMs = 10000;

  // Auth
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authForgotPassword = '/auth/forgot-password';

  // Dogs
  static const String dogs = '/dogs';
  static String dogById(String id) => '/dogs/$id';
  static String dogUsers(String dogId) => '/dogs/$dogId/users';
  static String dogInvite(String dogId) => '/dogs/$dogId/invite';
  static String dogRemoveUser(String dogId, String userId) => '/dogs/$dogId/users/$userId';

  // Collars
  static String collarById(String id) => '/collars/$id';
  static String collarStatus(String id) => '/collars/$id/status';
  static String collarLostMode(String id) => '/collars/$id/lost-mode';

  // GPS (under dog)
  static String gpsLatest(String dogId) => '/dogs/$dogId/gps/latest';
  static String gpsHistory(String dogId) => '/dogs/$dogId/gps/history';
  static String gpsTrails(String dogId) => '/dogs/$dogId/gps/trails';
  static String gpsTrailById(String dogId, String trailId) => '/dogs/$dogId/gps/trails/$trailId';
  static String gpsSync(String dogId) => '/dogs/$dogId/gps/sync';

  // Health (under dog)
  static String healthLatest(String dogId) => '/dogs/$dogId/health/latest';
  static String healthHistory(String dogId) => '/dogs/$dogId/health/history';
  static String healthActivity(String dogId) => '/dogs/$dogId/health/activity';
  static String healthSleep(String dogId) => '/dogs/$dogId/health/sleep';
  static String healthAnomalies(String dogId) => '/dogs/$dogId/health/anomalies';
  static String healthSync(String dogId) => '/dogs/$dogId/health/sync';
  static String healthExport(String dogId) => '/dogs/$dogId/health/export';

  // Alerts (under dog)
  static String alerts(String dogId) => '/dogs/$dogId/alerts';
  static String alertById(String dogId, String alertId) => '/dogs/$dogId/alerts/$alertId';
  static String alertRead(String dogId, String alertId) => '/dogs/$dogId/alerts/$alertId/read';
  static String alertsReadAll(String dogId) => '/dogs/$dogId/alerts/read-all';

  // User
  static const String userMe = '/users/me';
  static const String userPushToken = '/users/me/push-token';
  static const String userSubscription = '/users/me/subscription';
}
