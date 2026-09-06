import '../../domain/interfaces/repositories/i_auth_repository.dart';
import '../../domain/interfaces/services/i_notification_service.dart';

/// Initialise les notifications push (permission + token) et enregistre le
/// token côté backend. À appeler à la connexion — ne doit jamais bloquer ni
/// faire échouer le flux d'authentification : les appelants doivent traiter
/// ceci comme "best effort" (ne pas attendre / avaler les erreurs).
class RegisterPushTokenUseCase {
  final INotificationService _notifications;
  final IAuthRepository _authRepo;

  RegisterPushTokenUseCase(this._notifications, this._authRepo);

  Future<void> call() async {
    await _notifications.initialize();
    final token = await _notifications.getDeviceToken();
    if (token == null) return;
    await _authRepo.registerPushToken(token);
  }
}
