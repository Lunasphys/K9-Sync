import 'app_error.dart';

/// Local storage errors.
class StorageError extends AppError {
  const StorageError.corrupted()
      : super(
          code: 'STORAGE_001',
          message: 'Local database corrupted',
          userMessage: 'Base de données locale endommagée. Réinstallation nécessaire.',
        );

  const StorageError.quotaExceeded()
      : super(
          code: 'STORAGE_002',
          message: 'Local storage quota exceeded',
          userMessage: "Stockage local plein. Libérez de l'espace.",
        );
}
