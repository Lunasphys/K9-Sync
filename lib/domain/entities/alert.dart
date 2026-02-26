import 'package:equatable/equatable.dart';

import '../enums/alert_type.dart';

/// Domain entity: alert (geofence, temperature, lost, fall, etc.).
class Alert extends Equatable {
  final String id;
  final String dogId;
  final AlertType type;
  final String message;
  final bool isRead;
  final DateTime triggeredAt;

  const Alert({
    required this.id,
    required this.dogId,
    required this.type,
    required this.message,
    this.isRead = false,
    required this.triggeredAt,
  });

  @override
  List<Object?> get props => [id, dogId, type, message, isRead, triggeredAt];
}
