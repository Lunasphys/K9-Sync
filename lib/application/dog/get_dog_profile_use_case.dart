import '../../domain/entities/dog.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';

/// Get dog profile use case.
class GetDogProfileUseCase {
  final IDogRepository _repo;

  GetDogProfileUseCase(this._repo);

  Future<Dog?> call(String dogId) => _repo.getDogById(dogId);
}
