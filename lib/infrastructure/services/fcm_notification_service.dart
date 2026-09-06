import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/debug/debug_logger.dart';
import '../../domain/interfaces/services/i_notification_service.dart';
import '../../domain/models/notification_payload.dart';

const _androidChannel = AndroidNotificationChannel(
  'k9sync_alerts',
  'Alertes K9 Sync',
  description: 'Alertes santé, sécurité et activité de votre chien',
  importance: Importance.high,
);

/// Implémentation FCM + flutter_local_notifications.
///
/// [sendToUser]/[sendToGroup] ne sont PAS implémentées ici : l'envoi passe
/// obligatoirement par le backend (Firebase Admin SDK) — un client mobile
/// ne peut et ne doit jamais détenir les identifiants nécessaires pour
/// pousser une notification vers un autre utilisateur.
class FcmNotificationService implements INotificationService {
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await FirebaseMessaging.instance.requestPermission();

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      // App ouverte (foreground) : FCM n'affiche pas de notification
      // système par défaut — on l'affiche nous-mêmes localement.
      // App fermée ou en arrière-plan : gérée nativement par l'OS via le
      // plugin Google Services, rien à faire ici.
      FirebaseMessaging.onMessage.listen(_showLocalNotification);

      _initialized = true;
      DebugLogger.log('FCM', 'Initialized');
    } catch (e) {
      DebugLogger.log(
        'FCM',
        'Initialization failed (no Firebase config on this platform?): $e',
        level: LogLevel.warning,
      );
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    // Extra haptic nudge for critical alerts (see backend severity: 'critical'
    // on health anomalies — heart_rate/temperature past their threshold).
    // The system already plays the notification sound; this only adds
    // physical feedback, and only while the app is open — a closed app's
    // system notification is handled entirely by the OS, nothing to add here.
    if (message.data['severity'] == 'critical') {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      DebugLogger.log('FCM', 'getToken failed: $e', level: LogLevel.warning);
      return null;
    }
  }

  @override
  Future<void> sendToUser({
    required String userId,
    required NotificationPayload payload,
  }) async {
    throw UnsupportedError(
      'Sending push notifications is backend-only (see k9sync-backend '
      'pushNotifications.notifyDogAccessHolders). The app only registers '
      'its token and receives notifications, it never sends them.',
    );
  }

  @override
  Future<void> sendToGroup({
    required List<String> userIds,
    required NotificationPayload payload,
  }) async {
    throw UnsupportedError(
      'Sending push notifications is backend-only (see k9sync-backend '
      'pushNotifications.notifyDogAccessHolders). The app only registers '
      'its token and receives notifications, it never sends them.',
    );
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  }
}
