import 'package:dio/dio.dart';

import '../../core/debug/debug_logger.dart';
import '../../domain/entities/gps_location.dart';
import '../../domain/entities/trail.dart';
import '../../domain/interfaces/repositories/i_gps_repository.dart';
import '../../injection.dart';
import '../models/gps_location_model.dart';

/// GPS repository — 100% REST.
/// Replaces GpsRemoteDatasourceFirestore.
class GpsRepositoryImpl implements IGpsRepository {
  Dio get _dio => getIt<Dio>();

  @override
  Future<GpsLocation?> getLatestLocation(String dogId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/dogs/$dogId/gps/latest',
      );
      return _fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<GpsLocation>> getLocationHistory(
    String dogId, {
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/dogs/$dogId/gps/history',
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'limit': limit,
      },
    );
    final list = response.data ?? [];
    return list.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Trail>> getTrails(
    String dogId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _dio.get<List<dynamic>>('/dogs/$dogId/trails');
    final list = response.data ?? [];
    return list
        .map((e) => TrailModel.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  @override
  Future<Trail?> getTrailById(String dogId, String trailId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/dogs/$dogId/trails/$trailId',
      );
      return TrailModel.fromJson(response.data!).toEntity();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<String> createTrail(String dogId, Trail trail) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/dogs/$dogId/trails',
      data: {
        'startedAt': trail.startedAt.toIso8601String(),
        'endedAt': trail.endedAt.toIso8601String(),
        'distanceM': trail.distanceMeters.round(),
        'durationS': trail.duration.inSeconds,
        'pointsCount': trail.points.length,
      },
    );
    return response.data!['id'] as String;
  }

  @override
  Future<int> syncOfflineLocations(
    String dogId,
    List<GpsLocation> locations, {
    String? trailId,
  }) async {
    if (locations.isEmpty) return 0;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/dogs/$dogId/gps/sync',
        data: {
          'locations': locations
              .map(
                (l) => {
                  'latitude': l.latitude,
                  'longitude': l.longitude,
                  'accuracy': l.accuracy,
                  'recordedAt': l.recordedAt.toIso8601String(),
                },
              )
              .toList(),
          if (trailId != null) 'trailId': trailId,
        },
      );
      final synced = response.data?['synced'] as int? ?? 0;
      DebugLogger.sync('GPS sync: $synced locations sent');
      return synced;
    } catch (e) {
      DebugLogger.sync('GPS sync failed: $e');
      rethrow;
    }
  }
}

GpsLocation _fromJson(Map<String, dynamic> j) {
  return GpsLocation(
    id: j['id'] as String? ?? '',
    collarId: j['collarId'] as String? ?? '',
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    accuracy: j['accuracy'] != null ? (j['accuracy'] as num).toDouble() : null,
    recordedAt: DateTime.parse(j['recordedAt'] as String),
    syncedAt: j['syncedAt'] != null
        ? DateTime.tryParse(j['syncedAt'] as String)
        : null,
  );
}
