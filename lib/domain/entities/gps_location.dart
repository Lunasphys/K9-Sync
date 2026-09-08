import 'package:equatable/equatable.dart';

/// Domain entity: single GPS position.
class GpsLocation extends Equatable {
  final String id;
  final String collarId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime recordedAt;
  final DateTime? syncedAt;

  const GpsLocation({
    required this.id,
    required this.collarId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.recordedAt,
    this.syncedAt,
  });

  @override
  List<Object?> get props => [
    id,
    collarId,
    latitude,
    longitude,
    accuracy,
    recordedAt,
    syncedAt,
  ];
}
