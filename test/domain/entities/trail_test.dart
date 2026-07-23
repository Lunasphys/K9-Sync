import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:k9sync/domain/entities/trail.dart';

void main() {
  group('Trail.duration', () {
    test('computes the elapsed time between start and end', () {
      final trail = Trail(
        id: 't1',
        startedAt: DateTime(2026, 3, 14, 10, 0, 0),
        endedAt: DateTime(2026, 3, 14, 10, 32, 15),
        points: const [LatLng(45.7578, 4.8320)],
        distanceMeters: 1200,
      );
      expect(trail.duration, const Duration(minutes: 32, seconds: 15));
    });

    test('is zero when start and end are the same instant', () {
      final now = DateTime(2026, 3, 14, 10, 0, 0);
      final trail = Trail(
        id: 't2',
        startedAt: now,
        endedAt: now,
        points: const [],
        distanceMeters: 0,
      );
      expect(trail.duration, Duration.zero);
    });
  });

  group('Trail.toJson / Trail.fromJson round-trip', () {
    test('preserves all fields including multiple GPS points', () {
      final original = Trail(
        id: 'trail-42',
        startedAt: DateTime.utc(2026, 3, 14, 10, 0, 0),
        endedAt: DateTime.utc(2026, 3, 14, 10, 32, 15),
        points: const [
          LatLng(45.7578, 4.8320),
          LatLng(45.7580, 4.8325),
          LatLng(45.7585, 4.8330),
        ],
        distanceMeters: 87.42,
      );

      final json = original.toJson();
      final restored = Trail.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.startedAt, original.startedAt);
      expect(restored.endedAt, original.endedAt);
      expect(restored.distanceMeters, original.distanceMeters);
      expect(restored.points.length, 3);
      for (var i = 0; i < original.points.length; i++) {
        expect(restored.points[i].latitude, original.points[i].latitude);
        expect(restored.points[i].longitude, original.points[i].longitude);
      }
    });

    test('round-trips an empty points list', () {
      final now = DateTime.utc(2026, 1, 1);
      final original = Trail(
        id: 'empty',
        startedAt: now,
        endedAt: now,
        points: const [],
        distanceMeters: 0,
      );
      final restored = Trail.fromJson(original.toJson());
      expect(restored.points, isEmpty);
    });

    test('toJson stores dates as ISO 8601 strings', () {
      final trail = Trail(
        id: 't3',
        startedAt: DateTime.utc(2026, 3, 14, 10, 0, 0),
        endedAt: DateTime.utc(2026, 3, 14, 10, 5, 0),
        points: const [],
        distanceMeters: 0,
      );
      final json = trail.toJson();
      expect(json['startedAt'], '2026-03-14T10:00:00.000Z');
      expect(json['endedAt'], '2026-03-14T10:05:00.000Z');
    });

    test('toJson maps each point to a {lat, lng} entry', () {
      final trail = Trail(
        id: 't4',
        startedAt: DateTime.utc(2026, 1, 1),
        endedAt: DateTime.utc(2026, 1, 1),
        points: const [LatLng(1.5, -2.5)],
        distanceMeters: 0,
      );
      final json = trail.toJson();
      expect(json['points'], [
        {'lat': 1.5, 'lng': -2.5},
      ]);
    });
  });
}
