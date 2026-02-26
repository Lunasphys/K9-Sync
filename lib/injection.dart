import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import 'domain/interfaces/repositories/i_auth_repository.dart';
import 'domain/interfaces/repositories/i_dog_repository.dart';
import 'domain/interfaces/repositories/i_gps_repository.dart';
import 'domain/interfaces/repositories/i_health_repository.dart';
import 'domain/interfaces/repositories/i_alert_repository.dart';
import 'domain/interfaces/repositories/i_collar_repository.dart';
import 'domain/interfaces/services/i_notification_service.dart';
import 'domain/interfaces/services/i_health_data_service.dart';
import 'domain/interfaces/services/i_location_service.dart';
import 'domain/interfaces/services/i_mqtt_service.dart';
import 'infrastructure/datasources/remote/auth_remote_datasource.dart';
import 'infrastructure/datasources/remote/dog_remote_datasource.dart';
import 'infrastructure/datasources/remote/gps_remote_datasource_firestore.dart';
import 'infrastructure/datasources/remote/health_remote_datasource_firestore.dart';
import 'infrastructure/datasources/remote/alert_remote_datasource.dart';
import 'infrastructure/datasources/local/gps_local_datasource.dart';
import 'infrastructure/datasources/local/health_local_datasource.dart';
import 'infrastructure/repositories/auth_repository_impl.dart';
import 'infrastructure/repositories/dog_repository_impl.dart';
import 'infrastructure/repositories/gps_repository_impl.dart';
import 'infrastructure/repositories/health_repository_impl.dart';
import 'infrastructure/repositories/alert_repository_impl.dart';
import 'infrastructure/repositories/collar_repository_impl.dart';
import 'infrastructure/services/fcm_notification_service.dart';
import 'infrastructure/services/health_connect_service.dart';
import 'infrastructure/services/location_service.dart';
import 'infrastructure/services/mqtt_service.dart';

/// GetIt. MVP = 100 % Firebase (pas de Dio). [setupDependencies] après Firebase.initializeApp().
final getIt = GetIt.instance;

void setupDependencies() {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // Datasources (Firebase)
  getIt.registerLazySingleton<AuthRemoteDatasource>(
      () => AuthRemoteDatasourceFirebase(auth, firestore));
  getIt.registerLazySingleton<DogRemoteDatasource>(() => DogRemoteDatasource(firestore));
  getIt.registerLazySingleton<GpsRemoteDatasourceFirestore>(() => GpsRemoteDatasourceFirestore(firestore));
  getIt.registerLazySingleton<HealthRemoteDatasourceFirestore>(() => HealthRemoteDatasourceFirestore(firestore));
  getIt.registerLazySingleton<AlertRemoteDatasource>(() => AlertRemoteDatasource(firestore));
  getIt.registerLazySingleton<GpsLocalDatasource>(() => GpsLocalDatasourceImpl());
  getIt.registerLazySingleton<HealthLocalDatasource>(() => HealthLocalDatasourceImpl());

  // Repositories
  getIt.registerLazySingleton<IAuthRepository>(
      () => AuthRepositoryImpl(getIt<AuthRemoteDatasource>(), auth));
  getIt.registerLazySingleton<IDogRepository>(
      () => DogRepositoryImpl(getIt<DogRemoteDatasource>(), auth));
  getIt.registerLazySingleton<IGpsRepository>(() => GpsRepositoryImpl(
        getIt<GpsRemoteDatasourceFirestore>(),
        getIt<GpsLocalDatasource>(),
      ));
  getIt.registerLazySingleton<IHealthRepository>(
      () => HealthRepositoryImpl(getIt<HealthRemoteDatasourceFirestore>()));
  getIt.registerLazySingleton<IAlertRepository>(
      () => AlertRepositoryImpl(getIt<AlertRemoteDatasource>(), auth));
  getIt.registerLazySingleton<ICollarRepository>(() => CollarRepositoryImpl());

  // Services
  getIt.registerLazySingleton<INotificationService>(() => FcmNotificationService());
  getIt.registerLazySingleton<IHealthDataService>(() => HealthConnectService());
  getIt.registerLazySingleton<ILocationService>(() => LocationService());
  getIt.registerLazySingleton<IMqttService>(() => MqttService());
}
