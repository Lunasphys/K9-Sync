import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/alert.dart';
import '../../domain/enums/alert_type.dart';
import '_parsers.dart';

/// DTO Alert — Firestore ou REST (Prisma enum type, heart_rate → heartRate).
class AlertModel {
  final String id;
  final String dogId;
  final AlertType type;
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

  /// REST API : Prisma peut renvoyer 'heart_rate' (snake_case), Dart AlertType.heartRate.
  static AlertModel fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String;
    final alertType = rawType == 'heart_rate'
        ? AlertType.heartRate
        : AlertType.values.byName(rawType);
    return AlertModel(
      id: json['id'] as String,
      dogId: json['dogId'] as String,
      type: alertType,
      message: json['message'] as String,
      isRead: json['isRead'] as bool? ?? false,
      triggeredAt: parseDateTimeRequired(json['triggeredAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dogId': dogId,
        'type': type.name,
        'message': message,
        'isRead': isRead,
        'triggeredAt': triggeredAt.toIso8601String(),
      };

  static AlertModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final typeStr = (data['type'] as String?) ?? 'geofence';
    return AlertModel(
      id: doc.id,
      dogId: (data['dogId'] as String?) ?? '',
      type: _parseAlertType(typeStr),
      message: (data['message'] as String?) ?? '',
      isRead: data['isRead'] as bool? ?? false,
      triggeredAt: (data['triggeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'dogId': dogId,
        'type': type.name,
        'message': message,
        'isRead': isRead,
        'triggeredAt': Timestamp.fromDate(triggeredAt),
      };

  static AlertModel fromEntity(Alert e) => AlertModel(
        id: e.id,
        dogId: e.dogId,
        type: e.type,
        message: e.message,
        isRead: e.isRead,
        triggeredAt: e.triggeredAt,
      );

  Alert toEntity() => Alert(
        id: id,
        dogId: dogId,
        type: type,
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
