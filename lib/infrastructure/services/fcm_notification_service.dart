import '../../domain/interfaces/services/i_notification_service.dart';
import '../../domain/models/notification_payload.dart';

/// FCM implementation of INotificationService (stub — add firebase_messaging).
class FcmNotificationService implements INotificationService {
  @override
  Future<void> initialize() async {
    // TODO: FirebaseMessaging.instance.requestPermission, FlutterLocalNotificationsPlugin
  }

  @override
  Future<void> sendToUser({required String userId, required NotificationPayload payload}) async {}

  @override
  Future<void> sendToGroup({required List<String> userIds, required NotificationPayload payload}) async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}

  @override
  Future<String?> getDeviceToken() async => null;
}
