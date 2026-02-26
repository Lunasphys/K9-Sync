/// Noms des collections et champs Firestore (MVP). Single source of truth.
abstract final class FirebaseConstants {
  // Collections racines
  static const String users = 'users';
  static const String dogs = 'dogs';
  static const String userDogs = 'user_dogs';
  static const String collars = 'collars';

  // Sous-collections
  static const String dogsSub = 'dogs';
  static const String alertsSub = 'alerts';
  static const String gpsLocationsSub = 'gps_locations';
  static const String healthRecordsSub = 'health_records';
  static const String activityRecordsSub = 'activity_records';

  // Champs courants
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String userId = 'userId';
  static const String dogId = 'dogId';
  static const String collarId = 'collarId';
}
