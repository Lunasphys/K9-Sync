part of 'alerts_bloc.dart';

class AlertsState extends Equatable {
  final int selectedTabIndex;
  final bool silentMode;
  final bool realtimeTracking;

  const AlertsState({
    this.selectedTabIndex = 0,
    this.silentMode = false,
    this.realtimeTracking = true,
  });

  AlertsState copyWith({
    int? selectedTabIndex,
    bool? silentMode,
    bool? realtimeTracking,
  }) {
    return AlertsState(
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      silentMode: silentMode ?? this.silentMode,
      realtimeTracking: realtimeTracking ?? this.realtimeTracking,
    );
  }

  @override
  List<Object?> get props => [selectedTabIndex, silentMode, realtimeTracking];
}
