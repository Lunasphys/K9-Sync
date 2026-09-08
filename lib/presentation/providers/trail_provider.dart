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
// Hive box holding ids of trails whose backend summary POST failed —
// retried on app resume (see syncPendingTrails).
const _kPendingSyncBox = 'trail_pending_sync';

final trailListProvider = StateNotifierProvider<TrailNotifier, List<Trail>>(
  (ref) => TrailNotifier(),
);

class TrailNotifier extends StateNotifier<List<Trail>> {
  static const _collarId = 'SIM001';
  String? _cachedDogId;
  late final Future<void> _loaded;

  TrailNotifier() : super([]) {
    _loaded = _load();
  }

  Future<String?> getDogId() => _getDogId();

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
        start + (step * i).round(),
      );
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
            return Trail.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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

    // The trail is already visible locally at this point regardless of
    // what happens next — backend sync is best-effort from here on.
    final dogId = await _getDogId();
    if (dogId == null) return;
    await _syncTrailToBackend(dogId, trail);
  }

  /// Creates the trail summary server-side, then links this trail's GPS
  /// points to it. If the summary POST fails (e.g. network cut at the end
  /// of the walk), the trail is queued for a retry on next app resume
  /// instead of syncing the points unlinked.
  Future<void> _syncTrailToBackend(String dogId, Trail trail) async {
    String remoteTrailId;
    try {
      remoteTrailId = await getIt<IGpsRepository>().createTrail(dogId, trail);
    } catch (e) {
      DebugLogger.log(
        'TRAIL',
        'Create trail summary failed: $e — queued for retry',
      );
      await _queuePendingSync(trail.id);
      return;
    }

    final locations = _trailToGpsLocations(trail);
    if (locations.isNotEmpty) {
      try {
        await getIt<IGpsRepository>().syncOfflineLocations(
          dogId,
          locations,
          trailId: remoteTrailId,
        );
      } catch (e) {
        // Known limitation: the summary is saved but its points aren't.
        // We don't queue this for retry — the backend has no unique
        // constraint on GPS points, so resending them later would create
        // duplicates rather than fill the gap. The trail stays visible
        // locally with its points; only the backend copy is incomplete.
        DebugLogger.log('TRAIL', 'Sync trail points failed: $e');
      }
    }
    await _clearPendingSync(trail.id);
  }

  Future<void> _queuePendingSync(String trailId) async {
    final box = await Hive.openBox<String>(_kPendingSyncBox);
    await box.put(trailId, trailId);
  }

  Future<void> _clearPendingSync(String trailId) async {
    final box = await Hive.openBox<String>(_kPendingSyncBox);
    await box.delete(trailId);
  }

  /// Retries the backend summary sync for trails queued by
  /// [_syncTrailToBackend]. Call on app resume.
  Future<void> syncPendingTrails() async {
    final dogId = await _getDogId();
    if (dogId == null) return;

    final pendingBox = await Hive.openBox<String>(_kPendingSyncBox);
    if (pendingBox.isEmpty) return;

    final trailsBox = await Hive.openBox<String>(_kBoxName);
    for (final trailId in pendingBox.keys.toList()) {
      final raw = trailsBox.get(trailId);
      if (raw == null) {
        // Trail was deleted locally in the meantime — nothing to retry.
        await pendingBox.delete(trailId);
        continue;
      }
      try {
        final trail = Trail.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        await _syncTrailToBackend(dogId, trail);
      } catch (e) {
        DebugLogger.log('TRAIL', 'Retry sync failed for $trailId: $e');
      }
    }
  }

  /// Merges the local trail list with the backend's, so trails created on
  /// another device (or before a reinstall) also show up here. Local
  /// entries win on id conflicts since they carry the full GPS polyline,
  /// which the backend's list endpoint doesn't return.
  Future<void> refreshFromRemote() async {
    // Wait for the initial Hive load so this merge doesn't get clobbered by
    // it landing afterwards and overwriting state with local-only trails.
    await _loaded;
    final dogId = await _getDogId();
    if (dogId == null) return;

    try {
      final remoteTrails = await getIt<IGpsRepository>().getTrails(dogId);
      final localById = {for (final t in state) t.id: t};
      final seenIds = <String>{};
      final merged = <Trail>[];

      for (final remote in remoteTrails) {
        merged.add(localById[remote.id] ?? remote);
        seenIds.add(remote.id);
      }
      // Local trails not yet reflected server-side (e.g. summary sync
      // still pending) stay visible.
      for (final local in state) {
        if (!seenIds.contains(local.id)) merged.add(local);
      }

      merged.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      state = merged;
    } catch (e) {
      DebugLogger.log('TRAIL', 'Refresh from remote failed: $e');
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
