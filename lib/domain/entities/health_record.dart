import 'package:equatable/equatable.dart';

/// Domain entity: health snapshot (FC, temperature).
class HealthRecord extends Equatable {
  final String id;
  final String collarId;
  final int heartRate;
  final double temperature;
  final DateTime recordedAt;
  final DateTime? syncedAt;

  const HealthRecord({
    required this.id,
    required this.collarId,
    required this.heartRate,
    required this.temperature,
    required this.recordedAt,
    this.syncedAt,
  });

  @override
  List<Object?> get props => [id, collarId, heartRate, temperature, recordedAt, syncedAt];
}
