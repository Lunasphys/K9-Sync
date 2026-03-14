part of 'alerts_bloc.dart';

// Alert category for display
enum AlertCategory { security, health, activity, system }

// A single alert item — immutable
class AlertItem extends Equatable {
  final String id;
  final AlertCategory category;
  final String title;
  final String subtitle;
  final bool isRead;
  final bool isPriority;
  final DateTime triggeredAt;

  const AlertItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.triggeredAt,
    this.isRead = false,
    this.isPriority = false,
  });

  AlertItem copyWith({bool? isRead}) => AlertItem(
        id: id,
        category: category,
        title: title,
        subtitle: subtitle,
        triggeredAt: triggeredAt,
        isRead: isRead ?? this.isRead,
        isPriority: isPriority,
      );

  @override
  List<Object?> get props => [id, isRead];
}

class AlertsState extends Equatable {
  final int selectedTabIndex;
  final bool silentMode;
  final bool realtimeTracking;
  final List<AlertItem> alerts;

  const AlertsState({
    this.selectedTabIndex = 0,
    this.silentMode = false,
    this.realtimeTracking = true,
    this.alerts = const [],
  });

  // Filtered list based on selected tab
  List<AlertItem> get visibleAlerts => selectedTabIndex == 1
      ? alerts.where((a) => a.isPriority).toList()
      : alerts;

  int get unreadCount => alerts.where((a) => !a.isRead).length;

  AlertsState copyWith({
    int? selectedTabIndex,
    bool? silentMode,
    bool? realtimeTracking,
    List<AlertItem>? alerts,
  }) {
    return AlertsState(
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      silentMode: silentMode ?? this.silentMode,
      realtimeTracking: realtimeTracking ?? this.realtimeTracking,
      alerts: alerts ?? this.alerts,
    );
  }

  @override
  List<Object?> get props =>
      [selectedTabIndex, silentMode, realtimeTracking, alerts];
}
