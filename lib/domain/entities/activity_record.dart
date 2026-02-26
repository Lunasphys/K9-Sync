import 'package:equatable/equatable.dart';

import '../enums/sleep_phase.dart';
import '../enums/anomaly_type.dart';

/// Domain entity: activity summary (steps, active/rest, sleep, anomaly).
class ActivityRecord extends Equatable {
  final String id;
  final String collarId;
  final int steps;
  final int activeMinutes;
  final int restMinutes;
  final SleepPhase? sleepPhase;
  final bool anomalyDetected;
  final AnomalyType anomalyType;
  final DateTime recordedAt;
  final DateTime? syncedAt;

  const ActivityRecord({
    required this.id,
    required this.collarId,
    this.steps = 0,
    this.activeMinutes = 0,
    this.restMinutes = 0,
    this.sleepPhase,
    this.anomalyDetected = false,
    this.anomalyType = AnomalyType.none,
    required this.recordedAt,
    this.syncedAt,
  });

  @override
  List<Object?> get props =>
      [id, collarId, steps, activeMinutes, restMinutes, sleepPhase, anomalyDetected, anomalyType, recordedAt, syncedAt];
}
