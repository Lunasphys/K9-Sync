import '../../domain/entities/dog.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';

/// Met à jour le profil d'un chien.
class UpdateDogUseCase {
  UpdateDogUseCase(this._repo);
  final IDogRepository _repo;

  Future<Dog> call(String dogId, UpdateDogParams params) => _repo.updateDog(dogId, params);
}
