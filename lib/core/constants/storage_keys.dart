/// Keys for local storage (Hive / SharedPreferences). Do not change after release.
abstract final class StorageKeys {
  static const String prefix = 'k9sync_';

  static const String accessToken = '${prefix}access_token';
  static const String refreshToken = '${prefix}refresh_token';
  static const String userId = '${prefix}user_id';
  static const String onboardingDone = '${prefix}onboarding_done';
  static const String consentVersion = '${prefix}consent_version';

  static const String gpsBox = '${prefix}gps_offline';
  static const String healthBox = '${prefix}health_offline';
}
