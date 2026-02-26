import '../../domain/entities/gps_location.dart';
import '../../domain/interfaces/repositories/i_gps_repository.dart';

/// Get GPS history for a dog in a date range.
class GetLocationHistoryUseCase {
  final IGpsRepository _repo;

  GetLocationHistoryUseCase(this._repo);

  Future<List<GpsLocation>> call(
    String dogId, {
    required DateTime from,
    required DateTime to,
    int limit = 500,
  }) =>
      _repo.getLocationHistory(dogId, from: from, to: to, limit: limit);
}
