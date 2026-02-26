import '../../domain/interfaces/services/i_mqtt_service.dart';

/// MQTT service for collar (stub — add paho_mqtt or mqtt_client).
class MqttService implements IMqttService {
  @override
  Future<void> connect({required String collarSerial}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void subscribeToGps(MqttMessageCallback onMessage) {}

  @override
  void subscribeToHealth(MqttMessageCallback onMessage) {}

  @override
  void subscribeToStatus(MqttMessageCallback onMessage) {}

  @override
  void subscribeToAlert(MqttMessageCallback onMessage) {}

  @override
  Future<void> publishLostMode(String collarSerial, {required bool active}) async {}

  @override
  Future<void> publishBeep(String collarSerial, {required int durationMs}) async {}

  @override
  bool get isConnected => false;
}
