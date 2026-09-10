import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/screens/dog/dog_list_screen.dart';

class MockDogRepository extends Mock implements IDogRepository {}

Dog _dog(String id, String name) {
  final now = DateTime.utc(2026, 3, 14, 10, 0, 0);
  return Dog(id: id, name: name, createdAt: now, updatedAt: now);
}

void main() {
  late MockDogRepository mockDog;

  setUp(() {
    mockDog = MockDogRepository();

    if (getIt.isRegistered<IDogRepository>()) {
      getIt.unregister<IDogRepository>();
    }
    getIt.registerSingleton<IDogRepository>(mockDog);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('dogsProvider', () {
    test(
      'without invalidation, keeps serving the stale list — reproduces '
      'the "created dog does not show up" bug',
      () async {
        when(
          () => mockDog.getDogs(),
        ).thenAnswer((_) async => [_dog('dog-1', 'Visual Rex')]);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final first = await container.read(dogsProvider.future);
        expect(first.map((d) => d.name), ['Visual Rex']);

        // A dog gets created server-side (e.g. via DogSetupScreen._submit),
        // but nothing tells this container the cached list is out of date.
        when(
          () => mockDog.getDogs(),
        ).thenAnswer(
          (_) async => [_dog('dog-1', 'Visual Rex'), _dog('dog-2', 'Poulet')],
        );

        final stillCached = await container.read(dogsProvider.future);
        expect(stillCached.map((d) => d.name), ['Visual Rex']);
        verify(() => mockDog.getDogs()).called(1);
      },
    );

    test(
      'ref.invalidate(dogsProvider) forces a refetch and surfaces the '
      'newly created dog — the fix applied in DogSetupScreen._submit',
      () async {
        when(
          () => mockDog.getDogs(),
        ).thenAnswer((_) async => [_dog('dog-1', 'Visual Rex')]);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final first = await container.read(dogsProvider.future);
        expect(first.map((d) => d.name), ['Visual Rex']);

        when(
          () => mockDog.getDogs(),
        ).thenAnswer(
          (_) async =>
              [_dog('dog-1', 'Visual Rex'), _dog('dog-2', 'Diagnostic')],
        );

        // What DogSetupScreen._submit now does right after createDog().
        container.invalidate(dogsProvider);

        final refreshed = await container.read(dogsProvider.future);
        expect(refreshed.map((d) => d.name), ['Visual Rex', 'Diagnostic']);
        verify(() => mockDog.getDogs()).called(2);
      },
    );
  });
}
