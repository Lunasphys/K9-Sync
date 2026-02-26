import 'app_error.dart';

/// GPS / location errors.
class GPSError extends AppError {
  GPSError.insufficientAccuracy({required double accuracy})
      : super(
          code: 'GPS_001',
          message: 'GPS accuracy too low: ${accuracy}m',
          userMessage: null,
          context: {'accuracy': accuracy},
        );

  const GPSError.noSignal()
      : super(
          code: 'GPS_002',
          message: 'No GPS signal',
          userMessage: 'Signal GPS indisponible.',
        );

  const GPSError.corruptedOfflineData()
      : super(
          code: 'GPS_003',
          message: 'Corrupted offline GPS data',
          userMessage: 'Données hors-ligne corrompues. Synchronisation partielle.',
        );
}
