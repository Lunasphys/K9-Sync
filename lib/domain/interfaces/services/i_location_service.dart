/// Position GPS (téléphone — MVP sans collier).
class LocationPosition {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  const LocationPosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });
}

/// Contrat pour le GPS du téléphone (MVP : position en temps réel pendant la promenade).
abstract interface class ILocationService {
  /// Demande les permissions et retourne true si accordées.
  Future<bool> requestPermission();
  /// Dernière position connue (stream ou one-shot).
  Future<LocationPosition?> getLastPosition();
  /// Stream des positions en temps réel (pour carte live).
  Stream<LocationPosition> get positionStream;
  /// Vérifie si le service est disponible.
  bool get isServiceEnabled;
}
