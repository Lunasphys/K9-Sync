import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/domain/interfaces/repositories/i_alert_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/services/i_mqtt_service.dart';
import 'package:k9sync/injection.dart';

part 'alerts_event.dart';
part 'alerts_state.dart';

class AlertsBloc extends Bloc<AlertsEvent, AlertsState> {
  StreamSubscription<bool>? _connectionSub;
  static const _collarSerial = 'SIM001';

  final IAlertRepository _alertRepo = getIt<IAlertRepository>();

  // Cached first dog id for mark-as-read API calls (resolved once).
  String? _cachedDogId;

  // Deduplication window: ignore same type within 5 seconds
  final Map<String, DateTime> _lastAlertByType = {};
  static const _dedupWindow = Duration(seconds: 5);

  AlertsBloc() : super(const AlertsState()) {
    on<AlertsTabChanged>(_onTabChanged);
    on<AlertsSilentModeChanged>(_onSilentModeChanged);
    on<AlertsRealtimeTrackingChanged>(_onRealtimeTrackingChanged);
    on<AlertReceived>(_onAlertReceived);
    on<AlertMarkedRead>(_onAlertMarkedRead);
    on<AlertsAllMarkedRead>(_onAllMarkedRead);

    _initMqtt();
  }

  void _initMqtt() {
    final mqtt = getIt<IMqttService>();
    _connectionSub = mqtt.connectionState.listen((connected) {
      if (connected) _subscribeAlerts(mqtt);
    });
    mqtt.connect(collarSerial: _collarSerial);
  }

  void _subscribeAlerts(IMqttService mqtt) {
    // Only subscribe to the alert topic — health topic anomalies already
    // trigger an alert packet from the simulator, so listening to both
    // causes duplicates.
    mqtt.subscribeToAlert((topic, payload) {
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final alert = _parseAlert(json);
        if (!_isDuplicate(alert)) add(AlertReceived(alert));
      } catch (e) {
        DebugLogger.log('ALERTS', 'Alert parse error: $e');
      }
    });
  }

  // Returns true if same alert type was received within the dedup window
  bool _isDuplicate(AlertItem alert) {
    final key = alert.category.name;
    final last = _lastAlertByType[key];
    final now = DateTime.now();
    if (last != null && now.difference(last) < _dedupWindow) return true;
    _lastAlertByType[key] = now;
    return false;
  }

  AlertItem _parseAlert(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'system';
    final message = json['message'] as String? ?? 'Alerte reçue';
    final severity = json['severity'] as String? ?? 'normal';
    final triggeredAt =
        DateTime.tryParse(json['triggeredAt'] as String? ?? '') ??
            DateTime.now();

    return AlertItem(
      id: '${triggeredAt.millisecondsSinceEpoch}_$type',
      category: _categoryFromType(type),
      title: _titleFromType(type),
      subtitle: message,
      triggeredAt: triggeredAt,
      isPriority: severity == 'high' || severity == 'critical',
    );
  }

  AlertCategory _categoryFromType(String type) {
    switch (type) {
      case 'geofence':
      case 'lost':
        return AlertCategory.security;
      case 'heart_rate_critical':
      case 'temperature_critical':
      case 'fall':
        return AlertCategory.health;
      case 'bark':
        return AlertCategory.activity;
      default:
        return AlertCategory.system;
    }
  }

  String _titleFromType(String type) {
    switch (type) {
      case 'geofence':
        return 'Sortie de zone';
      case 'lost':
        return 'Mode chien perdu activé';
      case 'heart_rate_critical':
        return 'Fréquence cardiaque anormale';
      case 'temperature_critical':
        return 'Température anormale';
      case 'fall':
        return 'Chute détectée';
      case 'bark':
        return 'Aboiements excessifs';
      default:
        return 'Alerte système';
    }
  }

  void _onTabChanged(AlertsTabChanged event, Emitter<AlertsState> emit) =>
      emit(state.copyWith(selectedTabIndex: event.index));

  void _onSilentModeChanged(
          AlertsSilentModeChanged event, Emitter<AlertsState> emit) =>
      emit(state.copyWith(silentMode: event.enabled));

  void _onRealtimeTrackingChanged(
          AlertsRealtimeTrackingChanged event, Emitter<AlertsState> emit) =>
      emit(state.copyWith(realtimeTracking: event.enabled));

  void _onAlertReceived(AlertReceived event, Emitter<AlertsState> emit) {
    if (state.silentMode) return;
    // Secondary id-based dedup guard
    final exists = state.alerts.any((a) => a.id == event.alert.id);
    if (exists) return;
    emit(state.copyWith(alerts: [event.alert, ...state.alerts]));
    DebugLogger.log('ALERTS', 'Alert received: ${event.alert.title}');
  }

  Future<String?> _getDogId() async {
    if (_cachedDogId != null) return _cachedDogId;
    try {
      final user = await getIt<IAuthRepository>().getCurrentUser();
      if (user == null) return null;
      final dogs = await getIt<IDogRepository>().getDogs();
      final dogId = dogs.isNotEmpty ? dogs.first.id : null;
      if (dogId != null) _cachedDogId = dogId;
      return dogId;
    } catch (e) {
      DebugLogger.log('ALERTS', 'Resolve dogId failed: $e');
      return null;
    }
  }

  void _onAlertMarkedRead(
      AlertMarkedRead event, Emitter<AlertsState> emit) {
    final updated = state.alerts
        .map((a) => a.id == event.alertId ? a.copyWith(isRead: true) : a)
        .toList();
    emit(state.copyWith(alerts: updated));
    _getDogId().then((dogId) async {
      if (dogId == null) return;
      try {
        await _alertRepo.markAsRead(dogId, event.alertId);
      } catch (e) {
        DebugLogger.log('ALERTS', 'markAsRead API failed: $e');
      }
    });
  }

  void _onAllMarkedRead(
      AlertsAllMarkedRead event, Emitter<AlertsState> emit) {
    emit(state.copyWith(
        alerts: state.alerts.map((a) => a.copyWith(isRead: true)).toList()));
    _getDogId().then((dogId) async {
      if (dogId == null) return;
      try {
        await _alertRepo.markAllAsRead(dogId);
      } catch (e) {
        DebugLogger.log('ALERTS', 'markAllAsRead API failed: $e');
      }
    });
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    return super.close();
  }
}
