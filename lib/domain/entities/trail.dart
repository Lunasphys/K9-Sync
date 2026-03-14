import 'package:latlong2/latlong.dart';

class Trail {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<LatLng> points;
  final double distanceMeters;

  const Trail({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.points,
    required this.distanceMeters,
  });

  Duration get duration => endedAt.difference(startedAt);

  /// Serialize to plain Map for Hive JSON storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distanceMeters': distanceMeters,
        'points': points
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      };

  factory Trail.fromJson(Map<String, dynamic> json) => Trail(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        points: (json['points'] as List)
            .map((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ))
            .toList(),
      );
}
