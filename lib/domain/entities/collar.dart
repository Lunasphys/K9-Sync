import 'package:equatable/equatable.dart';

/// Domain entity: collar / device linked to a dog.
class Collar extends Equatable {
  final String id;
  final String? dogId;
  final String serialNumber;
  final int batteryLevel;
  final String? firmwareVersion;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Collar({
    required this.id,
    this.dogId,
    required this.serialNumber,
    required this.batteryLevel,
    this.firmwareVersion,
    required this.isOnline,
    this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, dogId, serialNumber, batteryLevel, firmwareVersion, isOnline, lastSeenAt, createdAt, updatedAt];
}

/// Collar status (battery, online, last seen).
class CollarStatus extends Equatable {
  final int battery;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? firmware;

  const CollarStatus({
    required this.battery,
    required this.isOnline,
    this.lastSeen,
    this.firmware,
  });

  @override
  List<Object?> get props => [battery, isOnline, lastSeen, firmware];
}
