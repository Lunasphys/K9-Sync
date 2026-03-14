import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/domain/entities/gps_location.dart' show GpsLocation;
import 'package:k9sync/domain/entities/trail.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_gps_repository.dart';
import 'package:k9sync/injection.dart';

// Hive box name — one box, each entry is a JSON-encoded Trail
const _kBoxName = 'trails';

final trailListProvider =
    StateNotifierProvider<TrailNotifier, List<Trail>>(
  (ref) => TrailNotifier(),
);

class TrailNotifier extends StateNotifier<List<Trail>> {
  static const _collarId = 'SIM001';
  String? _cachedDogId;

  TrailNotifier() : super([]) {
    _load();
  }

  Future<String?> _getDogId() async {
    if (_cachedDogId != null) return _cachedDogId;
    try {
      final user = await getIt<IAuthRepository>().getCurrentUser();
      if (user == null) return null;
      final dogs = await getIt<IDogRepository>().getDogs();
      final id = dogs.isNotEmpty ? dogs.first.id : null;
      if (id != null) _cachedDogId = id;
      return id;
    } catch (_) {
      return null;
    }
  }

  List<GpsLocation> _trailToGpsLocations(Trail trail) {
    final points = trail.points;
    if (points.isEmpty) return [];
    final start = trail.startedAt.millisecondsSinceEpoch;
    final end = trail.endedAt.millisecondsSinceEpoch;
    final step = points.length > 1 ? (end - start) / (points.length - 1) : 0.0;
    return points.asMap().entries.map((e) {
      final i = e.key;
      final p = e.value;
      final recordedAt = DateTime.fromMillisecondsSinceEpoch(
          start + (step * i).round());
      return GpsLocation(
        id: '${trail.id}_$i',
        collarId: _collarId,
        latitude: p.latitude,
        longitude: p.longitude,
        recordedAt: recordedAt,
      );
    }).toList();
  }

  // Load all persisted trails on startup
  Future<void> _load() async {
    final box = await Hive.openBox<String>(_kBoxName);
    final trails = box.values
        .map((raw) {
          try {
            return Trail.fromJson(
                jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Trail>()
        .toList();

    // Sort oldest → newest
    trails.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    state = trails;
  }

  Future<void> addTrail(Trail trail) async {
    final box = await Hive.openBox<String>(_kBoxName);
    // Key = trail id for easy lookup / deduplication
    await box.put(trail.id, jsonEncode(trail.toJson()));
    state = [...state, trail];

    // Sync trail points to backend (Task 5)
    final dogId = await _getDogId();
    if (dogId == null) return;
    final locations = _trailToGpsLocations(trail);
    if (locations.isEmpty) return;
    try {
      await getIt<IGpsRepository>().syncOfflineLocations(dogId, locations);
    } catch (e) {
      DebugLogger.log('TRAIL', 'Sync offline locations failed: $e');
    }
  }

  Future<void> deleteTrail(String id) async {
    final box = await Hive.openBox<String>(_kBoxName);
    await box.delete(id);
    state = state.where((t) => t.id != id).toList();
  }

  Future<void> clearAll() async {
    final box = await Hive.openBox<String>(_kBoxName);
    await box.clear();
    state = [];
  }
}
