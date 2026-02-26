import 'app_error.dart';

/// Health / sensor errors.
class HealthError extends AppError {
  HealthError.outOfRange({required String sensor, required dynamic value})
      : super(
          code: 'HEALTH_001',
          message: 'Sensor out of range: $sensor=$value',
          userMessage: 'Mesure $sensor anormale. Vérifiez le capteur.',
          context: {'sensor': sensor, 'value': value},
        );

  HealthError.unavailable({required String sensor})
      : super(
          code: 'HEALTH_002',
          message: 'Sensor unavailable: $sensor',
          userMessage: 'Capteur $sensor non disponible sur ce collier.',
          context: {'sensor': sensor},
        );
}
