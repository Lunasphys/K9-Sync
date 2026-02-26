import 'app_error.dart';

/// Business rule errors.
class BusinessError extends AppError {
  BusinessError.premiumRequired({required String feature})
      : super(
          code: 'BIZ_003',
          message: 'Premium required: $feature',
          userMessage: 'Cette fonctionnalité nécessite un abonnement Premium.',
          context: {'feature': feature},
        );

  BusinessError.geofenceTooSmall({required int radiusM})
      : super(
          code: 'BIZ_004',
          message: 'Geofence radius too small: ${radiusM}m',
          userMessage: 'Le rayon de la zone doit être d\'au moins 10 mètres.',
          context: {'radius': radiusM},
        );
}
