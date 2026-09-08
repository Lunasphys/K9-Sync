import 'package:flutter_test/flutter_test.dart';

import 'package:k9sync/infrastructure/models/gps_location_model.dart';

void main() {
  group('TrailModel.fromJson', () {
    test('parses a summary row (GET /dogs/:dogId/trails) with no points', () {
      final json = {
        'id': 'trail-1',
        'collarId': 'collar-1',
        'startedAt': '2026-03-14T10:00:00.000Z',
        'endedAt': '2026-03-14T10:32:15.000Z',
        'distanceM': 1200,
        'durationS': 1935,
        'pointsCount': 42,
      };

      final model = TrailModel.fromJson(json);

      expect(model.id, 'trail-1');
      expect(model.distanceM, 1200);
      expect(model.pointsCount, 42);
      expect(model.points, isEmpty);
    });

    test('parses a full row (GET /dogs/:dogId/trails/:trailId) with points', () {
      final json = {
        'id': 'trail-1',
        'collarId': 'collar-1',
        'startedAt': '2026-03-14T10:00:00.000Z',
        'endedAt': '2026-03-14T10:32:15.000Z',
        'distanceM': 1200,
        'durationS': 1935,
        'pointsCount': 2,
        'points': [
          {
            'id': 'p1',
            'collarId': 'collar-1',
            'latitude': 45.7578,
            'longitude': 4.8320,
            'recordedAt': '2026-03-14T10:00:00.000Z',
          },
          {
            'id': 'p2',
            'collarId': 'collar-1',
            'latitude': 45.7580,
            'longitude': 4.8325,
            'recordedAt': '2026-03-14T10:32:15.000Z',
          },
        ],
      };

      final model = TrailModel.fromJson(json);

      expect(model.points.length, 2);
      expect(model.points[0].latitude, 45.7578);
      expect(model.points[1].longitude, 4.8325);
    });
  });

  group('TrailModel.toEntity', () {
    test('maps summary fields onto the domain Trail (empty polyline)', () {
      final model = TrailModel(
        id: 'trail-1',
        collarId: 'collar-1',
        startedAt: DateTime.utc(2026, 3, 14, 10, 0, 0),
        endedAt: DateTime.utc(2026, 3, 14, 10, 32, 15),
        distanceM: 1200,
        durationS: 1935,
        pointsCount: 42,
      );

      final trail = model.toEntity();

      expect(trail.id, 'trail-1');
      expect(trail.startedAt, model.startedAt);
      expect(trail.endedAt, model.endedAt);
      expect(trail.distanceMeters, 1200.0);
      expect(trail.points, isEmpty);
    });

    test('maps GPS points onto LatLng entries', () {
      final json = {
        'id': 'trail-1',
        'collarId': 'collar-1',
        'startedAt': '2026-03-14T10:00:00.000Z',
        'endedAt': '2026-03-14T10:32:15.000Z',
        'distanceM': 1200,
        'durationS': 1935,
        'pointsCount': 1,
        'points': [
          {
            'id': 'p1',
            'collarId': 'collar-1',
            'latitude': 45.7578,
            'longitude': 4.8320,
            'recordedAt': '2026-03-14T10:00:00.000Z',
          },
        ],
      };

      final trail = TrailModel.fromJson(json).toEntity();

      expect(trail.points.length, 1);
      expect(trail.points.first.latitude, 45.7578);
      expect(trail.points.first.longitude, 4.8320);
    });
  });
}
