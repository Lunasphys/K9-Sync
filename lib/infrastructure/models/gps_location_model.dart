import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/gps_location.dart';
import '_parsers.dart';

/// DTO GPS — Firestore ou REST (Prisma Decimal lat/lng en String).
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

  /// REST API : Prisma Decimal(10,7) lat/lng en String.
  static GpsLocationModel fromJson(Map<String, dynamic> json) {
    return GpsLocationModel(
      id: json['id'] as String,
      collarId: json['collarId'] as String,
      latitude: parseDecimal(json['latitude']) ?? 0,
      longitude: parseDecimal(json['longitude']) ?? 0,
      accuracy: parseDecimal(json['accuracy']),
      recordedAt: parseDateTimeRequired(json['recordedAt']),
      syncedAt: parseDateTime(json['syncedAt']),
    );
  }

  /// Pour POST /gps/sync (sync offline).
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        'recordedAt': recordedAt.toIso8601String(),
      };

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

/// DTO Trail — REST (Prisma distanceM, durationS, pointsCount, points optionnel).
class TrailModel {
  final String id;
  final String collarId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int distanceM;
  final int durationS;
  final int pointsCount;
  final List<GpsLocation> points;

  const TrailModel({
    required this.id,
    required this.collarId,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.durationS,
    required this.pointsCount,
    this.points = const [],
  });

  static TrailModel fromJson(Map<String, dynamic> json) {
    return TrailModel(
      id: json['id'] as String,
      collarId: json['collarId'] as String,
      startedAt: parseDateTimeRequired(json['startedAt']),
      endedAt: parseDateTimeRequired(json['endedAt']),
      distanceM: json['distanceM'] as int? ?? 0,
      durationS: json['durationS'] as int? ?? 0,
      pointsCount: json['pointsCount'] as int? ?? 0,
      points: json['points'] == null
          ? []
          : (json['points'] as List)
              .map((p) => GpsLocationModel.fromJson(p as Map<String, dynamic>).toEntity())
              .toList(),
    );
  }

  Trail toEntity(String dogId) => Trail(
        id: id,
        dogId: dogId,
        startAt: startedAt,
        endAt: endedAt,
        distanceMeters: distanceM.toDouble(),
        pointCount: pointsCount,
      );
}
