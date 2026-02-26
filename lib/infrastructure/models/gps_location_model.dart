import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/gps_location.dart';

/// DTO GPS — Firestore dogs/{dogId}/gps_locations/{locationId}.
class GpsLocationModel {
  final String id;
  final String collarId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime recordedAt;
  final DateTime? syncedAt;

  const GpsLocationModel({
    required this.id,
    required this.collarId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.recordedAt,
    this.syncedAt,
  });

  static GpsLocationModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GpsLocationModel(
      id: doc.id,
      collarId: (data['collarId'] as String?) ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      recordedAt: (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      syncedAt: (data['syncedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'collarId': collarId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'recordedAt': Timestamp.fromDate(recordedAt),
        'syncedAt': syncedAt != null ? Timestamp.fromDate(syncedAt!) : FieldValue.serverTimestamp(),
      };

  static GpsLocationModel fromEntity(GpsLocation e) => GpsLocationModel(
        id: e.id,
        collarId: e.collarId,
        latitude: e.latitude,
        longitude: e.longitude,
        accuracy: e.accuracy,
        recordedAt: e.recordedAt,
        syncedAt: e.syncedAt,
      );

  GpsLocation toEntity() => GpsLocation(
        id: id,
        collarId: collarId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        recordedAt: recordedAt,
        syncedAt: syncedAt,
      );
}
