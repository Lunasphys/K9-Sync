import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dog.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';
import '../../injection.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum DogLoadStatus { initial, loading, loaded, saving, error }

class DogState {
  final Dog? dog;
  final DogLoadStatus status;
  final String? errorMessage;

  const DogState({
    this.dog,
    this.status = DogLoadStatus.initial,
    this.errorMessage,
  });

  DogState copyWith({
    Dog? dog,
    DogLoadStatus? status,
    String? errorMessage,
  }) =>
      DogState(
        dog: dog ?? this.dog,
        status: status ?? this.status,
        errorMessage: errorMessage,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Family provider — one notifier per dogId.
final dogProvider =
    StateNotifierProvider.family<DogNotifier, DogState, String>(
  (ref, dogId) => DogNotifier(dogId),
);

// ── Notifier ──────────────────────────────────────────────────────────────────

class DogNotifier extends StateNotifier<DogState> {
  DogNotifier(this._dogId) : super(const DogState()) {
    unawaited(load());
  }

  final String _dogId;
  final IDogRepository _repo = getIt<IDogRepository>();

  Future<void> load() async {
    state = state.copyWith(status: DogLoadStatus.loading, errorMessage: null);
    try {
      final dog = await _repo.getDogById(_dogId);
      state = state.copyWith(dog: dog, status: DogLoadStatus.loaded);
    } catch (e) {
      state = state.copyWith(
        status: DogLoadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// PATCH /dogs/:dogId — partial update, returns updated Dog.
  Future<bool> save({
    String? name,
    String? breed,
    double? weight,
    DateTime? birthDate,
    List<String>? allergies,
    String? photoUrl,
    String? sex,
  }) async {
    state = state.copyWith(status: DogLoadStatus.saving, errorMessage: null);
    try {
      final updated = await _repo.updateDog(
        _dogId,
        UpdateDogParams(
          name: name,
          breed: breed,
          birthDate: birthDate,
          weight: weight,
          sex: sex,
          allergies: allergies,
          photoUrl: photoUrl,
        ),
      );
      state = state.copyWith(dog: updated, status: DogLoadStatus.loaded);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: DogLoadStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}
