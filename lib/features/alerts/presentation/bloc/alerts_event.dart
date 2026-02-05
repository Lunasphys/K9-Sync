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
