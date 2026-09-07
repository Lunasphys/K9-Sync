import 'package:equatable/equatable.dart';

/// Domain entity: the dog's single safety-zone circle (geofence). Scope
/// réduit — un seul cercle par chien, pas de zones multiples ni d'horaires.
class Geofence extends Equatable {
  final String id;
  final String dogId;
  final double latitude;
  final double longitude;
  final int radiusM;

  /// Whether the dog's last known position was inside the zone — mirrors
  /// the server-side transition state used to avoid re-alerting on every
  /// GPS point while the dog stays outside.
  final bool isInside;

  const Geofence({
    required this.id,
    required this.dogId,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.isInside,
  });

  @override
  List<Object?> get props => [id, dogId, latitude, longitude, radiusM, isInside];
}
