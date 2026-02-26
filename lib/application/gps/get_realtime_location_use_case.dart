import '../../domain/entities/gps_location.dart';
import '../../domain/interfaces/repositories/i_gps_repository.dart';

/// Get latest GPS position for a dog.
class GetRealtimeLocationUseCase {
  final IGpsRepository _repo;

  GetRealtimeLocationUseCase(this._repo);

  Future<GpsLocation?> call(String dogId) => _repo.getLatestLocation(dogId);
}
