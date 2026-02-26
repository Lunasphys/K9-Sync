import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/health_record.dart';
import '_parsers.dart';

/// DTO HealthRecord — Firestore ou REST (Prisma Decimal temperature, heartRate nullable).
class HealthRecordModel {
  final String id;
  final String collarId;
  final int heartRate;
  final double temperature;
  final DateTime recordedAt;
  final DateTime? syncedAt;

  const HealthRecordModel({
    required this.id,
    required this.collarId,
    required this.heartRate,
    required this.temperature,
    required this.recordedAt,
    this.syncedAt,
  });

  /// REST API : Prisma heartRate nullable, temperature Decimal.
  static HealthRecordModel fromJson(Map<String, dynamic> json) {
    return HealthRecordModel(
      id: json['id'] as String,
      collarId: json['collarId'] as String,
      heartRate: parseInt(json['heartRate']) ?? 0,
      temperature: parseDecimal(json['temperature']) ?? 0,
      recordedAt: parseDateTimeRequired(json['recordedAt']),
      syncedAt: parseDateTime(json['syncedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'collarId': collarId,
        if (heartRate > 0) 'heartRate': heartRate,
        'temperature': temperature,
        'recordedAt': recordedAt.toIso8601String(),
        if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
      };

  static HealthRecordModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return HealthRecordModel(
      id: doc.id,
      collarId: (data['collarId'] as String?) ?? '',
      heartRate: (data['heartRate'] as int?) ?? 0,
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0,
      recordedAt: (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'collarId': collarId,
        'heartRate': heartRate,
        'temperature': temperature,
        'recordedAt': Timestamp.fromDate(recordedAt),
        'syncedAt': syncedAt != null ? Timestamp.fromDate(syncedAt!) : FieldValue.serverTimestamp(),
      };

  static HealthRecordModel fromEntity(HealthRecord e) => HealthRecordModel(
        id: e.id,
        collarId: e.collarId,
        heartRate: e.heartRate,
        temperature: e.temperature,
        recordedAt: e.recordedAt,
        syncedAt: e.syncedAt,
      );

  HealthRecord toEntity() => HealthRecord(
        id: id,
        collarId: collarId,
        heartRate: heartRate,
        temperature: temperature,
        recordedAt: recordedAt,
        syncedAt: syncedAt,
      );
}

/// Réponse GET /health/activity (Prisma).
class ActivitySummary {
  final String date;
  final int totalSteps;
  final int activeMinutes;
  final int restMinutes;
  final int anomalyCount;

  const ActivitySummary({
    required this.date,
    required this.totalSteps,
    required this.activeMinutes,
    required this.restMinutes,
    required this.anomalyCount,
  });

  static ActivitySummary fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      date: json['date'] as String,
      totalSteps: json['totalSteps'] as int? ?? 0,
      activeMinutes: json['activeMinutes'] as int? ?? 0,
      restMinutes: json['restMinutes'] as int? ?? 0,
      anomalyCount: json['anomalyCount'] as int? ?? 0,
    );
  }
}

/// Réponse GET /health/sleep (Prisma).
class SleepAnalysis {
  final String date;
  final int deepMinutes;
  final int lightMinutes;
  final int totalMinutes;

  const SleepAnalysis({
    required this.date,
    required this.deepMinutes,
    required this.lightMinutes,
    required this.totalMinutes,
  });

  static SleepAnalysis fromJson(Map<String, dynamic> json) {
    return SleepAnalysis(
      date: json['date'] as String,
      deepMinutes: json['deepMinutes'] as int? ?? 0,
      lightMinutes: json['lightMinutes'] as int? ?? 0,
      totalMinutes: json['totalMinutes'] as int? ?? 0,
    );
  }
}
