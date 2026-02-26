import '../../domain/entities/collar.dart';
import '_parsers.dart';

/// DTO Collar — REST (Prisma camelCase, batteryLevel nullable).
class CollarModel extends Collar {
  const CollarModel({
    required super.id,
    super.dogId,
    required super.serialNumber,
    required super.batteryLevel,
    super.firmwareVersion,
    required super.isOnline,
    super.lastSeenAt,
    required super.createdAt,
    required super.updatedAt,
  });

  static CollarModel fromJson(Map<String, dynamic> json) {
    return CollarModel(
      id: json['id'] as String,
      dogId: json['dogId'] as String?,
      serialNumber: json['serialNumber'] as String,
      batteryLevel: parseInt(json['batteryLevel']) ?? 0,
      firmwareVersion: json['firmwareVersion'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeenAt: parseDateTime(json['lastSeenAt']),
      createdAt: parseDateTimeRequired(json['createdAt']),
      updatedAt: parseDateTimeRequired(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (dogId != null) 'dogId': dogId,
        'serialNumber': serialNumber,
        if (batteryLevel > 0) 'batteryLevel': batteryLevel,
        if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
        'isOnline': isOnline,
        if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

/// Réponse GET /collars/:id/status (Prisma).
class CollarStatusModel {
  final int? battery;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? firmware;

  const CollarStatusModel({
    this.battery,
    required this.isOnline,
    this.lastSeen,
    this.firmware,
  });

  static CollarStatusModel fromJson(Map<String, dynamic> json) {
    return CollarStatusModel(
      battery: parseInt(json['battery']),
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: parseDateTime(json['lastSeen']),
      firmware: json['firmware'] as String?,
    );
  }

  CollarStatus toEntity() => CollarStatus(
        battery: battery ?? 0,
        isOnline: isOnline,
        lastSeen: lastSeen,
        firmware: firmware,
      );
}
