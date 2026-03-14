import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/health_record.dart';
import '../../domain/interfaces/repositories/i_health_repository.dart';
import '../datasources/remote/health_remote_datasource.dart';
import '../datasources/remote/health_remote_datasource_firestore.dart';

const _kHealthOfflineBox = 'health_offline';

/// Implémentation santé MVP : Firestore dogs/{dogId}/health_records + REST sync.
class HealthRepositoryImpl implements IHealthRepository {
  HealthRepositoryImpl(this._remote, this._syncRemote);
  final HealthRemoteDatasourceFirestore _remote;
  final HealthRemoteDatasource _syncRemote;

  @override
  Future<HealthRecord?> getLatestHealth(String dogId) async {
    final m = await _remote.getLatest(dogId);
    return m?.toEntity();
  }

  @override
  Future<List<HealthRecord>> getHealthHistory(
    String dogId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final list = await _remote.getHistory(dogId, from: from, to: to);
    return list.map((e) => e.toEntity()).toList();
  }

  @override
  Future<ActivitySummary?> getActivitySummary(String dogId, DateTime date) async => null;

  @override
  Future<SleepAnalysis?> getSleepAnalysis(String dogId, DateTime date) async => null;

  @override
  Future<List<AnomalyRecord>> getAnomalies(String dogId, {DateTime? from, DateTime? to}) async => [];

  @override
  Future<int> syncOfflineHealth(String dogId, List<HealthRecord> records) async {
    final box = await Hive.openBox<String>(_kHealthOfflineBox);
    final entries = box.toMap();
    if (entries.isEmpty) return 0;
    final list = <Map<String, dynamic>>[];
    final keysToDelete = <String>[];
    for (final e in entries.entries) {
      try {
        final json = jsonDecode(e.value) as Map<String, dynamic>;
        list.add({
          'heartRate': (json['heartRate'] as num?)?.toInt() ?? 0,
          'temperature': (json['temperature'] as num?)?.toDouble() ?? 0.0,
          'steps': (json['steps'] as num?)?.toInt() ?? 0,
          'activeMinutes': (json['activeMinutes'] as num?)?.toInt() ?? 0,
          'anomalyDetected': json['anomalyDetected'] as bool? ?? false,
          'anomalyType': json['anomalyType'] as String? ?? 'none',
          'recordedAt': json['recordedAt'] as String? ?? e.key,
        });
        keysToDelete.add(e.key);
      } catch (_) {
        // Skip corrupted entry
      }
    }
    if (list.isEmpty) return 0;
    try {
      final synced = await _syncRemote.syncHealth(dogId, list);
      for (final k in keysToDelete) {
        await box.delete(k);
      }
      return synced;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<List<int>> exportPdfBytes(String dogId, {DateTime? from, DateTime? to}) async => [];
}
