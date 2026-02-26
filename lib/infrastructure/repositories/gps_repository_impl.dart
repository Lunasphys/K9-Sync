import '../../domain/entities/gps_location.dart';
import '../../domain/interfaces/repositories/i_gps_repository.dart';
import '../datasources/local/gps_local_datasource.dart';
import '../datasources/remote/gps_remote_datasource_firestore.dart';
import '../models/gps_location_model.dart';

/// Implémentation GPS MVP : Firestore dogs/{dogId}/gps_locations + Hive offline (squelette).
class GpsRepositoryImpl implements IGpsRepository {
  GpsRepositoryImpl(this._remote, this._local);
  final GpsRemoteDatasourceFirestore _remote;
  // ignore: unused_field — utilisé pour sync offline Hive en impl complète
  final GpsLocalDatasource _local;

  @override
  Future<GpsLocation?> getLatestLocation(String dogId) async {
    final m = await _remote.getLatest(dogId);
    return m?.toEntity();
  }

  @override
  Future<List<GpsLocation>> getLocationHistory(
    String dogId, {
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) async {
    final list = await _remote.getHistory(dogId, from: from, to: to, limit: limit);
    return list.map((e) => e.toEntity()).toList();
  }

  @override
  Future<List<Trail>> getTrails(String dogId, {DateTime? from, DateTime? to}) async => [];

  @override
  Future<Trail?> getTrailById(String dogId, String trailId) async => null;

  @override
  Future<int> syncOfflineLocations(String dogId, List<GpsLocation> locations) async {
    final models = locations.map((e) => GpsLocationModel.fromEntity(e)).toList();
    await _remote.addLocations(dogId, models);
    return models.length;
  }
}
