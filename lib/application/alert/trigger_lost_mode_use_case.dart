import '../../domain/interfaces/repositories/i_collar_repository.dart';

/// Trigger lost mode on collar (beep/light).
class TriggerLostModeUseCase {
  final ICollarRepository _repo;

  TriggerLostModeUseCase(this._repo);

  Future<void> call(String collarId, {required bool activate}) =>
      _repo.triggerLostMode(collarId, activate: activate);
}
