import 'package:flutter_test/flutter_test.dart';

// Health anomaly detection logic — thresholds used in health.controller.ts
// and replicated here for unit testing the Flutter-side anomaly detection.
//
// Thresholds (matching backend):
//   Heart rate: < 50 bpm or > 180 bpm → anomaly
//   Temperature: < 36.0°C or > 39.5°C → anomaly

bool isHeartRateAnomaly(int bpm) => bpm < 50 || bpm > 180;
bool isTemperatureAnomaly(double celsius) =>
    celsius < 36.0 || celsius > 39.5;

void main() {
  group('Health anomaly detection — heart rate', () {
    test('normal heart rate is not an anomaly', () {
      expect(isHeartRateAnomaly(80), isFalse);
      expect(isHeartRateAnomaly(50), isFalse); // boundary — exactly 50 is ok
      expect(isHeartRateAnomaly(180), isFalse); // boundary — exactly 180 is ok
      expect(isHeartRateAnomaly(120), isFalse);
    });

    test('heart rate below 50 bpm is an anomaly', () {
      expect(isHeartRateAnomaly(49), isTrue);
      expect(isHeartRateAnomaly(35), isTrue);
      expect(isHeartRateAnomaly(0), isTrue);
    });

    test('heart rate above 180 bpm is an anomaly', () {
      expect(isHeartRateAnomaly(181), isTrue);
      expect(isHeartRateAnomaly(220), isTrue);
      expect(isHeartRateAnomaly(300), isTrue);
    });
  });

  group('Health anomaly detection — temperature', () {
    test('normal temperature is not an anomaly', () {
      expect(isTemperatureAnomaly(38.0), isFalse);
      expect(isTemperatureAnomaly(36.0), isFalse); // boundary ok
      expect(isTemperatureAnomaly(39.5), isFalse); // boundary ok
      expect(isTemperatureAnomaly(37.5), isFalse);
    });

    test('temperature below 36.0°C is an anomaly', () {
      expect(isTemperatureAnomaly(35.9), isTrue);
      expect(isTemperatureAnomaly(34.0), isTrue);
    });

    test('temperature above 39.5°C is an anomaly', () {
      expect(isTemperatureAnomaly(39.6), isTrue);
      expect(isTemperatureAnomaly(41.0), isTrue);
    });
  });
}
