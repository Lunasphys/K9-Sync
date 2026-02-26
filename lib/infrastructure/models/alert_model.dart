import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/alert.dart';
import '../../domain/enums/alert_type.dart';

/// DTO Alert — Firestore users/{userId}/alerts/{alertId}.
class AlertModel {
  final String id;
  final String dogId;
  final String type;
  final String message;
  final bool isRead;
  final DateTime triggeredAt;

  const AlertModel({
    required this.id,
    required this.dogId,
    required this.type,
    required this.message,
    this.isRead = false,
    required this.triggeredAt,
  });

  static AlertModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AlertModel(
      id: doc.id,
      dogId: (data['dogId'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'info',
      message: (data['message'] as String?) ?? '',
      isRead: data['isRead'] as bool? ?? false,
      triggeredAt: (data['triggeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'dogId': dogId,
        'type': type,
        'message': message,
        'isRead': isRead,
        'triggeredAt': Timestamp.fromDate(triggeredAt),
      };

  static AlertModel fromEntity(Alert e) => AlertModel(
        id: e.id,
        dogId: e.dogId,
        type: e.type.name,
        message: e.message,
        isRead: e.isRead,
        triggeredAt: e.triggeredAt,
      );

  Alert toEntity() => Alert(
        id: id,
        dogId: dogId,
        type: _parseAlertType(type),
        message: message,
        isRead: isRead,
        triggeredAt: triggeredAt,
      );

  static AlertType _parseAlertType(String s) {
    final lower = s.replaceAll('_', '').toLowerCase();
    for (final e in AlertType.values) {
      if (e.name.replaceAll('_', '').toLowerCase() == lower) return e;
    }
    return AlertType.heartRate;
  }
}
