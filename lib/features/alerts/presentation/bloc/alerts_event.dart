part of 'alerts_bloc.dart';

sealed class AlertsEvent extends Equatable {
  const AlertsEvent();

  @override
  List<Object?> get props => [];
}

final class AlertsTabChanged extends AlertsEvent {
  final int index;
  const AlertsTabChanged(this.index);

  @override
  List<Object?> get props => [index];
}

final class AlertsSilentModeChanged extends AlertsEvent {
  final bool enabled;
  const AlertsSilentModeChanged(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

final class AlertsRealtimeTrackingChanged extends AlertsEvent {
  final bool enabled;
  const AlertsRealtimeTrackingChanged(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

// Fired when a new alert arrives from MQTT
final class AlertReceived extends AlertsEvent {
  final AlertItem alert;
  const AlertReceived(this.alert);

  @override
  List<Object?> get props => [alert];
}

// Mark one alert as read
final class AlertMarkedRead extends AlertsEvent {
  final String alertId;
  const AlertMarkedRead(this.alertId);

  @override
  List<Object?> get props => [alertId];
}

// Mark all alerts as read
final class AlertsAllMarkedRead extends AlertsEvent {
  const AlertsAllMarkedRead();
}
