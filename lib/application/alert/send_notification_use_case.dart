import '../../domain/models/notification_payload.dart';
import '../../domain/interfaces/services/i_notification_service.dart';

/// Send notification (e.g. to group for lost dog).
class SendNotificationUseCase {
  final INotificationService _service;

  SendNotificationUseCase(this._service);

  Future<void> sendToUser({required String userId, required NotificationPayload payload}) =>
      _service.sendToUser(userId: userId, payload: payload);

  Future<void> sendToGroup({required List<String> userIds, required NotificationPayload payload}) =>
      _service.sendToGroup(userIds: userIds, payload: payload);
}
