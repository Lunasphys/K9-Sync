/// Health / sensor value normalization and thresholds (from doc).
abstract final class HealthUtils {
  /// Normal heart rate range (bpm).
  static const int heartRateMin = 50;
  static const int heartRateMax = 180;

  /// Normal body temperature range (°C).
  static const double tempMin = 36.0;
  static const double tempMax = 39.5;

  /// Critical battery level (alert).
  static const int batteryCriticalPercent = 20;

  /// Check if heart rate is in normal range.
  static bool isHeartRateNormal(int bpm) => bpm >= heartRateMin && bpm <= heartRateMax;

  /// Check if temperature is in normal range.
  static bool isTemperatureNormal(double celsius) => celsius >= tempMin && celsius <= tempMax;

  /// Clamp heart rate to physical range (0–300 from schema).
  static int clampHeartRate(int bpm) {
    if (bpm < 0) return 0;
    if (bpm > 300) return 300;
    return bpm;
  }
}
