import '../enums/notification_priority.dart';

/// Notification type (alert, reminder, etc.).
enum NotificationType { alert, reminder, info, lostDog, collarBattery }

/// Payload for sending a notification (domain model).
class NotificationPayload {
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final NotificationPriority priority;

  const NotificationPayload({
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.priority = NotificationPriority.normal,
  });
}
