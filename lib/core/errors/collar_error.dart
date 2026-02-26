import 'app_error.dart';

/// Collier / device errors.
class CollarError extends AppError {
  CollarError.notFound({required String serial})
      : super(
          code: 'COLLAR_001',
          message: 'Collar not found: $serial',
          userMessage: "Collier introuvable. Vérifiez l'appairage.",
          context: {'serial': serial},
        );

  CollarError.mqttFailed({required String serial, Object? cause})
      : super(
          code: 'COLLAR_002',
          message: 'MQTT connection failed: $serial',
          userMessage: 'Connexion au collier impossible.',
          cause: cause,
          context: {'serial': serial},
        );

  CollarError.lowBattery({required int level})
      : super(
          code: 'COLLAR_005',
          message: 'Critical battery: $level%',
          userMessage: 'Batterie critique ($level%). Rechargez le collier.',
          context: {'battery': level},
        );
}
