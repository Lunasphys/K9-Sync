import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dog.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';
import '../../injection.dart';

final dogRepositoryProvider = Provider<IDogRepository>((ref) => getIt<IDogRepository>());

/// Liste des chiens de l'utilisateur connecté.
final dogListProvider = FutureProvider<List<Dog>>((ref) async {
  return ref.read(dogRepositoryProvider).getDogs();
});
