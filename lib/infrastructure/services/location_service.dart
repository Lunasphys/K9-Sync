import 'package:geolocator/geolocator.dart';

import '../../domain/interfaces/services/i_location_service.dart';

/// Service GPS téléphone (MVP : position pendant la promenade).
class LocationService implements ILocationService {
  @override
  Future<bool> requestPermission() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      return requested == LocationPermission.whileInUse || requested == LocationPermission.always;
    }
    return status == LocationPermission.whileInUse || status == LocationPermission.always;
  }

  @override
  Future<LocationPosition?> getLastPosition() async {
    final pos = await Geolocator.getLastKnownPosition();
    if (pos == null) return null;
    return LocationPosition(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      timestamp: pos.timestamp,
    );
  }

  @override
  Stream<LocationPosition> get positionStream => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).map((pos) => LocationPosition(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            timestamp: pos.timestamp,
          ));

  @override
  bool get isServiceEnabled => true;
}
