import 'package:flutter_test/flutter_test.dart';
import 'package:k9sync/core/utils/gps_utils.dart';

void main() {
  group('GpsUtils.distanceMeters', () {
    test('same point returns 0', () {
      expect(
        GpsUtils.distanceMeters(45.75, 4.83, 45.75, 4.83),
        closeTo(0, 1e-6),
      );
    });

    test('1 degree of longitude at the equator is ~111.19 km', () {
      // Independently derived: R * radians(1) for a great circle along the equator.
      expect(GpsUtils.distanceMeters(0, 0, 0, 1), closeTo(111194.93, 1));
    });

    test('1 degree of latitude along a meridian is ~111.19 km', () {
      expect(GpsUtils.distanceMeters(0, 0, 1, 0), closeTo(111194.93, 1));
    });

    test('antipodal points are ~half the Earth\'s circumference apart', () {
      expect(GpsUtils.distanceMeters(0, 0, 0, 180), closeTo(20015086.80, 1));
    });

    test(
      'Paris to Lyon matches an independently computed great-circle distance',
      () {
        expect(
          GpsUtils.distanceMeters(48.8566, 2.3522, 45.7578, 4.8320),
          closeTo(391976.70, 1),
        );
      },
    );

    test(
      'Paris to London matches an independently computed great-circle distance',
      () {
        expect(
          GpsUtils.distanceMeters(48.8566, 2.3522, 51.5074, -0.1278),
          closeTo(343556.06, 1),
        );
      },
    );

    test('is symmetric — distance A→B equals distance B→A', () {
      final ab = GpsUtils.distanceMeters(45.7578, 4.8320, 48.8566, 2.3522);
      final ba = GpsUtils.distanceMeters(48.8566, 2.3522, 45.7578, 4.8320);
      expect(ab, closeTo(ba, 1e-6));
    });

    test(
      'small displacement (~11m) stays in a plausible walking-distance range',
      () {
        // ~0.0001 deg of latitude is roughly 11m — sanity-checks the formula at
        // collar/GPS-tracking scale, not just planetary scale.
        final d = GpsUtils.distanceMeters(45.7578, 4.8320, 45.7579, 4.8320);
        expect(d, greaterThan(5));
        expect(d, lessThan(20));
      },
    );
  });

  group('GpsUtils.bearing', () {
    test('due east along the equator is 90°', () {
      expect(GpsUtils.bearing(0, 0, 0, 1), closeTo(90, 1e-6));
    });

    test('due north is 0°', () {
      expect(GpsUtils.bearing(0, 0, 1, 0), closeTo(0, 1e-6));
    });

    test('due south is 180°', () {
      expect(GpsUtils.bearing(0, 0, -1, 0), closeTo(180, 1e-6));
    });

    test('due west is 270° (wrapped from a negative angle)', () {
      expect(GpsUtils.bearing(0, 0, 0, -1), closeTo(270, 1e-6));
    });

    test('same point has a well-defined bearing (no NaN)', () {
      expect(GpsUtils.bearing(45.75, 4.83, 45.75, 4.83).isNaN, isFalse);
    });

    test('result is always within [0, 360)', () {
      final points = [
        [10.0, 10.0],
        [-10.0, -10.0],
        [89.0, 179.0],
        [-89.0, -179.0],
      ];
      for (final p in points) {
        final b = GpsUtils.bearing(0, 0, p[0], p[1]);
        expect(b, greaterThanOrEqualTo(0));
        expect(b, lessThan(360));
      }
    });
  });
}
