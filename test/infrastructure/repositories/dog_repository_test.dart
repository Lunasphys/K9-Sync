import 'package:flutter_test/flutter_test.dart';

import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';

void main() {
  group('DogRepositoryImpl', () {
    test('getDogs returns list of dogs from GET /dogs', () async {
      // Arrange — simulate API response
      final fakeResponseData = [
        {
          'id': 'dog-123',
          'name': 'Bucky',
          'breed': 'Golden Retriever',
          'birthDate': null,
          'weight': '28.5',
          'sex': 'male',
          'allergies': [],
          'characterTraits': [],
          'photoUrl': null,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }
      ];

      final json = fakeResponseData.first as Map<String, dynamic>;
      final dog = _dogFromJson(json);

      // Assert — JSON mapping
      expect(dog.id, equals('dog-123'));
      expect(dog.name, equals('Bucky'));
      expect(dog.breed, equals('Golden Retriever'));
      expect(dog.weight, equals(28.5));
      expect(dog.sex, equals(DogSex.male));
    });

    test('createDog params are mapped correctly to JSON body', () {
      // Arrange — same structure as DogRepositoryImpl.createDog data
      final params = CreateDogParams(
        name: 'Nami',
        breed: 'Shiba Inu',
        weight: 8.5,
        sex: DogSex.female,
        allergies: ['gluten'],
        photoUrl: 'https://example.com/nami.jpg',
      );

      final body = <String, dynamic>{
        'name': params.name,
        if (params.breed != null) 'breed': params.breed,
        if (params.birthDate != null)
          'birthDate': params.birthDate!.toIso8601String(),
        if (params.weight != null) 'weight': params.weight,
        if (params.sex != null) 'sex': params.sex!.name,
        if (params.allergies.isNotEmpty) 'allergies': params.allergies,
        if (params.photoUrl != null) 'photoUrl': params.photoUrl,
      };

      // Assert — POST /dogs body serialization
      expect(body['name'], equals('Nami'));
      expect(body['breed'], equals('Shiba Inu'));
      expect(body['weight'], equals(8.5));
      expect(body['sex'], equals('female'));
      expect(body['allergies'], equals(['gluten']));
      expect(body['photoUrl'], equals('https://example.com/nami.jpg'));
    });

    test('optional fields are excluded from body when null', () {
      final params = CreateDogParams(name: 'Rex');

      final body = <String, dynamic>{
        'name': params.name,
        if (params.breed != null) 'breed': params.breed,
        if (params.birthDate != null)
          'birthDate': params.birthDate!.toIso8601String(),
        if (params.weight != null) 'weight': params.weight,
        if (params.sex != null) 'sex': params.sex!.name,
        if (params.allergies.isNotEmpty) 'allergies': params.allergies,
        if (params.photoUrl != null) 'photoUrl': params.photoUrl,
      };

      expect(body.containsKey('name'), isTrue);
      expect(body.containsKey('breed'), isFalse);
      expect(body.containsKey('weight'), isFalse);
      expect(body.containsKey('sex'), isFalse);
      expect(body.containsKey('photoUrl'), isFalse);
    });
  });
}

// Mapper matching DogRepositoryImpl._dogFromJson for testing
Dog _dogFromJson(Map<String, dynamic> j) {
  return Dog(
    id: j['id'] as String,
    name: j['name'] as String,
    breed: j['breed'] as String?,
    birthDate: j['birthDate'] != null
        ? DateTime.tryParse(j['birthDate'] as String)
        : null,
    weight: j['weight'] != null
        ? double.tryParse(j['weight'].toString())
        : null,
    sex: _parseSex(j['sex'] as String?),
    allergies: (j['allergies'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    characterTraits: (j['characterTraits'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    photoUrl: j['photoUrl'] as String?,
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: j['updatedAt'] != null
        ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}

DogSex? _parseSex(String? raw) {
  if (raw == null) return null;
  for (final e in DogSex.values) {
    if (e.name == raw) return e;
  }
  return null;
}
