import '../../entities/collar.dart';

/// Contract for collar/device (Clean Architecture — domain).
abstract interface class ICollarRepository {
  Future<Collar?> getCollarById(String collarId);
  Future<Collar> updateCollar(String collarId, {String? dogId});
  Future<CollarStatus> getCollarStatus(String collarId);
  Future<void> triggerLostMode(String collarId, {required bool activate});
}
