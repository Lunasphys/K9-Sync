import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../core/debug/debug_logger.dart';
import '../../domain/interfaces/services/i_mqtt_service.dart';

class MqttService implements IMqttService {
  MqttServerClient? _client;
  String? _collarSerial;

  final List<StreamSubscription> _subscriptions = [];

  // Broadcasts true on connect, false on disconnect
  final _connectionController = StreamController<bool>.broadcast();

  // Prevents multiple concurrent reconnect loops
  bool _reconnecting = false;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  String _topic(String type) => 'k9sync/collar/$_collarSerial/$type';

  @override
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  Future<void> connect({required String collarSerial}) async {
    _collarSerial = collarSerial;
    _reconnecting = false;
    await _doConnect();
  }

  // Internal connect — called on first connect and on each retry
  Future<void> _doConnect() async {
    if (_collarSerial == null) return;

    final broker = String.fromEnvironment(
      'MQTT_BROKER_URL',
      defaultValue: '192.168.1.113',
    );
    const port = 1883;
    final clientId = 'k9sync_flutter_${_collarSerial}_${DateTime.now().millisecondsSinceEpoch}';

    // Cancel previous subscriptions before creating a new client
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _client = MqttServerClient.withPort(broker, clientId, port);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;
    _client!.autoReconnect = false;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await _client!.connect();
    } catch (e) {
      DebugLogger.collar('MQTT connect failed: $e');
      _client?.disconnect();
      // _onDisconnected will trigger the retry loop
    }
  }

  @override
  Future<void> disconnect() async {
    _reconnecting = false;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _client?.disconnect();
    DebugLogger.collar('MQTT manually disconnected');
  }

  @override
  void subscribeToGps(MqttMessageCallback onMessage) {
    _subscribe(_topic('gps'), onMessage);
  }

  @override
  void subscribeToHealth(MqttMessageCallback onMessage) {
    _subscribe(_topic('health'), onMessage);
  }

  @override
  void subscribeToStatus(MqttMessageCallback onMessage) {
    _subscribe(_topic('status'), onMessage);
  }

  @override
  void subscribeToAlert(MqttMessageCallback onMessage) {
    _subscribe(_topic('alert'), onMessage);
  }

  @override
  Future<void> publishLostMode(String collarSerial, {required bool active}) async {
    _publish(
      'k9sync/collar/$collarSerial/cmd/lost-mode',
      jsonEncode({'active': active}),
    );
  }

  @override
  Future<void> publishBeep(String collarSerial, {required int durationMs}) async {
    _publish(
      'k9sync/collar/$collarSerial/cmd/beep',
      jsonEncode({'duration': durationMs}),
    );
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  void _subscribe(String topic, MqttMessageCallback onMessage) {
    // No isConnected check — we only reach here via connectionState emitting true
    // after _onConnected, so the client is connected
    _client!.subscribe(topic, MqttQos.atLeastOnce);
    DebugLogger.collar(
      'Subscribed to topic: $topic — updates null: ${_client!.updates == null}',
    );

    final sub = _client!.updates!.listen((messages) {
      for (final msg in messages) {
        if (msg.topic != topic) continue;
        final payload = MqttPublishPayload.bytesToStringAsString(
          (msg.payload as MqttPublishMessage).payload.message,
        );
        DebugLogger.collar('MQTT ← $topic : $payload');
        onMessage(msg.topic, payload);
      }
    });

    _subscriptions.add(sub);
  }

  void _publish(String topic, String payload) {
    if (!isConnected) return;
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    DebugLogger.collar('MQTT → $topic : $payload');
  }

  void _onConnected() {
    _reconnecting = false;
    _retryCount = 0;
    DebugLogger.collar('MQTT connected (serial=$_collarSerial)');

    // Small delay to ensure connectionStatus is updated before emitting
    Future.delayed(const Duration(milliseconds: 200), () {
      _connectionController.add(true);
    });
  }

  void _onDisconnected() {
    DebugLogger.collar('MQTT disconnected (serial=$_collarSerial)');
    _connectionController.add(false);
    _scheduleReconnect();
  }

  // Retry with exponential backoff: 3s, 6s, 12s, capped at 30s
  int _retryCount = 0;

  void _scheduleReconnect() {
    if (_reconnecting) return;
    _reconnecting = true;

    final delaySeconds = [3, 6, 12, 30][_retryCount.clamp(0, 3)];
    _retryCount++;

    DebugLogger.collar(
      'MQTT retry #$_retryCount in ${delaySeconds}s (serial=$_collarSerial)',
    );

    Future.delayed(Duration(seconds: delaySeconds), () async {
      if (!_reconnecting) return; // disconnect() was called manually
      _reconnecting = false;
      await _doConnect();
    });
  }
}
