import '../../domain/entities/collar.dart';
import '../../domain/interfaces/repositories/i_collar_repository.dart';

/// Implémentation collier MVP : stub (Firestore collars/ en V1).
class CollarRepositoryImpl implements ICollarRepository {
  @override
  Future<Collar?> getCollarById(String collarId) async => null;

  @override
  Future<Collar> updateCollar(String collarId, {String? dogId}) async {
    throw UnimplementedError('CollarRepositoryImpl.updateCollar');
  }

  @override
  Future<CollarStatus> getCollarStatus(String collarId) async {
    return const CollarStatus(battery: 0, isOnline: false, lastSeen: null, firmware: null);
  }

  @override
  Future<void> triggerLostMode(String collarId, {required bool activate}) async {}
}
