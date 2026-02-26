/// Callback for incoming MQTT messages (collar → app).
typedef MqttMessageCallback = void Function(String topic, String payload);

/// Contract for MQTT (collier ESP32) — subscribe to collar topics.
abstract interface class IMqttService {
  Future<void> connect({required String collarSerial});
  Future<void> disconnect();
  void subscribeToGps(MqttMessageCallback onMessage);
  void subscribeToHealth(MqttMessageCallback onMessage);
  void subscribeToStatus(MqttMessageCallback onMessage);
  void subscribeToAlert(MqttMessageCallback onMessage);
  Future<void> publishLostMode(String collarSerial, {required bool active});
  Future<void> publishBeep(String collarSerial, {required int durationMs});
  bool get isConnected;
}
