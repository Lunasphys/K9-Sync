import 'package:flutter_test/flutter_test.dart';
import 'package:k9sync/core/utils/health_utils.dart';

void main() {
  group('HealthUtils.isHeartRateNormal', () {
    test('typical resting/active heart rates are normal', () {
      expect(HealthUtils.isHeartRateNormal(75), isTrue);
      expect(HealthUtils.isHeartRateNormal(120), isTrue);
    });

    test('lower boundary (50 bpm) is normal', () {
      expect(HealthUtils.isHeartRateNormal(50), isTrue);
    });

    test('upper boundary (180 bpm) is normal', () {
      expect(HealthUtils.isHeartRateNormal(180), isTrue);
    });

    test('just below the lower boundary (49 bpm) is an anomaly', () {
      expect(HealthUtils.isHeartRateNormal(49), isFalse);
    });

    test('just above the upper boundary (181 bpm) is an anomaly', () {
      expect(HealthUtils.isHeartRateNormal(181), isFalse);
    });

    test('extreme low (0 bpm) is an anomaly', () {
      expect(HealthUtils.isHeartRateNormal(0), isFalse);
    });

    test('extreme high (300 bpm) is an anomaly', () {
      expect(HealthUtils.isHeartRateNormal(300), isFalse);
    });
  });

  group('HealthUtils.isTemperatureNormal', () {
    test('typical body temperature is normal', () {
      expect(HealthUtils.isTemperatureNormal(38.0), isTrue);
    });

    test('lower boundary (36.0°C) is normal', () {
      expect(HealthUtils.isTemperatureNormal(36.0), isTrue);
    });

    test('upper boundary (39.5°C) is normal', () {
      expect(HealthUtils.isTemperatureNormal(39.5), isTrue);
    });

    test('just below the lower boundary (35.9°C) is an anomaly', () {
      expect(HealthUtils.isTemperatureNormal(35.9), isFalse);
    });

    test('just above the upper boundary (39.6°C) is an anomaly', () {
      expect(HealthUtils.isTemperatureNormal(39.6), isFalse);
    });

    test('hypothermic extreme (30.0°C) is an anomaly', () {
      expect(HealthUtils.isTemperatureNormal(30.0), isFalse);
    });

    test('hyperthermic extreme (42.0°C) is an anomaly', () {
      expect(HealthUtils.isTemperatureNormal(42.0), isFalse);
    });
  });

  group('HealthUtils.clampHeartRate', () {
    test('value within the physical range is unchanged', () {
      expect(HealthUtils.clampHeartRate(90), equals(90));
    });

    test('negative value clamps to 0', () {
      expect(HealthUtils.clampHeartRate(-10), equals(0));
    });

    test('value above 300 clamps to 300', () {
      expect(HealthUtils.clampHeartRate(500), equals(300));
    });

    test('lower boundary (0) is unchanged', () {
      expect(HealthUtils.clampHeartRate(0), equals(0));
    });

    test('upper boundary (300) is unchanged', () {
      expect(HealthUtils.clampHeartRate(300), equals(300));
    });
  });
}
