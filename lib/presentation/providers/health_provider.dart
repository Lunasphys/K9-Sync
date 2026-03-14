import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/interfaces/repositories/i_health_repository.dart';
import '../../injection.dart';

final healthRepositoryProvider =
    Provider<IHealthRepository>((ref) => getIt<IHealthRepository>());

// Hive box for daily activity persistence
const _kActivityBox = 'daily_activity';
// Hive box for offline health buffer (sync to backend later)
const _kHealthOfflineBox = 'health_offline';
const _kHealthOfflineMaxEntries = 500;

// ── HealthSnapshot ────────────────────────────────────────────────────────────

class HealthSnapshot {
  final int heartRate;
  final double temperature;
  final int steps;
  final int activeMinutes;
  final bool anomalyDetected;
  final String anomalyType;
  final DateTime recordedAt;

  const HealthSnapshot({
    required this.heartRate,
    required this.temperature,
    required this.steps,
    required this.activeMinutes,
    required this.anomalyDetected,
    required this.anomalyType,
    required this.recordedAt,
  });

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) {
    return HealthSnapshot(
      heartRate: (json['heartRate'] as num?)?.toInt() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      activeMinutes: (json['activeMinutes'] as num?)?.toInt() ?? 0,
      anomalyDetected: json['anomalyDetected'] as bool? ?? false,
      anomalyType: json['anomalyType'] as String? ?? 'none',
      recordedAt: DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'heartRate': heartRate,
        'temperature': temperature,
        'steps': steps,
        'activeMinutes': activeMinutes,
        'anomalyDetected': anomalyDetected,
        'anomalyType': anomalyType,
        'recordedAt': recordedAt.toIso8601String(),
      };
}

// ── DailyActivity — persisted in Hive ────────────────────────────────────────

class DailyActivity {
  final String date; // YYYY-MM-DD
  final int steps;
  final int activeMinutes;

  const DailyActivity({
    required this.date,
    required this.steps,
    required this.activeMinutes,
  });

  DailyActivity copyWith({int? steps, int? activeMinutes}) => DailyActivity(
        date: date,
        steps: steps ?? this.steps,
        activeMinutes: activeMinutes ?? this.activeMinutes,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'steps': steps,
        'activeMinutes': activeMinutes,
      };

  factory DailyActivity.fromJson(Map<String, dynamic> json) => DailyActivity(
        date: json['date'] as String,
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        activeMinutes: (json['activeMinutes'] as num?)?.toInt() ?? 0,
      );

  // Today's key in Hive
  static String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

// ── HealthState ───────────────────────────────────────────────────────────────

class HealthState {
  final HealthSnapshot? latest;
  final List<HealthSnapshot> history;

  // Today's accumulated activity — loaded from Hive on startup
  final DailyActivity todayActivity;

  HealthState({
    this.latest,
    this.history = const [],
    DailyActivity? todayActivity,
  }) : todayActivity = todayActivity ??
            DailyActivity(
              date: DailyActivity.todayKey,
              steps: 0,
              activeMinutes: 0,
            );

  HealthState copyWith({
    HealthSnapshot? latest,
    List<HealthSnapshot>? history,
    DailyActivity? todayActivity,
  }) {
    return HealthState(
      latest: latest ?? this.latest,
      history: history ?? this.history,
      todayActivity: todayActivity ?? this.todayActivity,
    );
  }
}

// ── HealthNotifier ────────────────────────────────────────────────────────────

final healthProvider =
    StateNotifierProvider<HealthNotifier, HealthState>(
        (ref) => HealthNotifier());

class HealthNotifier extends StateNotifier<HealthState> {
  static const _maxHistory = 60;

  HealthNotifier() : super(HealthState()) {
    _loadTodayActivity();
  }

  // Load today's activity from Hive — resets automatically on a new day
  Future<void> _loadTodayActivity() async {
    final box = await Hive.openBox<String>(_kActivityBox);
    final key = DailyActivity.todayKey;
    final raw = box.get(key);
    if (raw == null) return; // New day — start from zero

    try {
      final activity = DailyActivity.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      state = state.copyWith(todayActivity: activity);
    } catch (_) {
      // Corrupted entry — ignore and start fresh
    }
  }

  // Persist today's activity to Hive
  Future<void> _saveTodayActivity(DailyActivity activity) async {
    final box = await Hive.openBox<String>(_kActivityBox);
    await box.put(activity.date, jsonEncode(activity.toJson()));
  }

  void onSnapshot(HealthSnapshot snap) {
    // Update rolling history for charts
    final updated = [...state.history, snap];
    if (updated.length > _maxHistory) updated.removeAt(0);

    // Accumulate today's steps and active minutes
    // Take the max to avoid double-counting — simulator sends cumulative values
    final current = state.todayActivity;
    final newActivity = current.copyWith(
      steps: snap.steps > current.steps ? snap.steps : current.steps,
      activeMinutes: snap.activeMinutes > current.activeMinutes
          ? snap.activeMinutes
          : current.activeMinutes,
    );

    state = state.copyWith(
      latest: snap,
      history: updated,
      todayActivity: newActivity,
    );

    // Persist asynchronously — no await to keep UI responsive
    _saveTodayActivity(newActivity);

    // Buffer snapshot for offline sync (Task 3)
    _bufferSnapshotForSync(snap);
  }

  /// Write snapshot to Hive offline box for later sync. Max 500 entries.
  Future<void> _bufferSnapshotForSync(HealthSnapshot snap) async {
    try {
      final box = await Hive.openBox<String>(_kHealthOfflineBox);
      final key = snap.recordedAt.toIso8601String();
      await box.put(key, jsonEncode(snap.toJson()));
      if (box.length > _kHealthOfflineMaxEntries) {
        final keys = box.keys.toList()..sort();
        while (box.length > _kHealthOfflineMaxEntries && keys.isNotEmpty) {
          await box.delete(keys.removeAt(0));
        }
      }
    } catch (_) {
      // Non-critical; skip on error
    }
  }
}
