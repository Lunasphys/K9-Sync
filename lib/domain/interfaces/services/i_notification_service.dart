import '../../models/notification_payload.dart';

/// Contract for push/local notifications (FCM, OneSignal, etc.) — pattern Adapter.
abstract interface class INotificationService {
  Future<void> initialize();
  Future<void> sendToUser({required String userId, required NotificationPayload payload});
  Future<void> sendToGroup({required List<String> userIds, required NotificationPayload payload});
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
  Future<String?> getDeviceToken();
}
