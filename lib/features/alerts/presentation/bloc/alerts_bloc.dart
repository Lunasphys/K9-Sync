import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'alerts_event.dart';
part 'alerts_state.dart';

/// Bloc for alerts screen: tab filter and quick settings toggles.
class AlertsBloc extends Bloc<AlertsEvent, AlertsState> {
  AlertsBloc() : super(const AlertsState()) {
    on<AlertsTabChanged>(_onTabChanged);
    on<AlertsSilentModeChanged>(_onSilentModeChanged);
    on<AlertsRealtimeTrackingChanged>(_onRealtimeTrackingChanged);
  }

  void _onTabChanged(AlertsTabChanged event, Emitter<AlertsState> emit) {
    emit(state.copyWith(selectedTabIndex: event.index));
  }

  void _onSilentModeChanged(AlertsSilentModeChanged event, Emitter<AlertsState> emit) {
    emit(state.copyWith(silentMode: event.enabled));
  }

  void _onRealtimeTrackingChanged(AlertsRealtimeTrackingChanged event, Emitter<AlertsState> emit) {
    emit(state.copyWith(realtimeTracking: event.enabled));
  }
}
