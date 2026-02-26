import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/health_record.dart';

/// DTO HealthRecord — Firestore dogs/{dogId}/health_records/{recordId}.
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
