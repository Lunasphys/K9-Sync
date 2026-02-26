import '../../domain/entities/dog.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';

/// Create dog use case.
class CreateDogUseCase {
  final IDogRepository _repo;

  CreateDogUseCase(this._repo);

  Future<Dog> call(CreateDogParams params) => _repo.createDog(params);
}
