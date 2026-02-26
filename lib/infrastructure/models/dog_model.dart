import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/dog.dart';

/// DTO Dog — Firestore dogs/{dogId} ou users/{userId}/dogs/{dogId}.
class DogModel {
  final String id;
  final String name;
  final String? breed;
  final DateTime? birthDate;
  final double? weight;
  final String? sex;
  final List<String> allergies;
  final List<String> characterTraits;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DogModel({
    required this.id,
    required this.name,
    this.breed,
    this.birthDate,
    this.weight,
    this.sex,
    this.allergies = const [],
    this.characterTraits = const [],
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  static DogModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DogModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      breed: data['breed'] as String?,
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      weight: (data['weight'] as num?)?.toDouble(),
      sex: data['sex'] as String?,
      allergies: (data['allergies'] as List<dynamic>?)?.cast<String>() ?? [],
      characterTraits: (data['characterTraits'] as List<dynamic>?)?.cast<String>() ?? [],
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'breed': breed,
        'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
        'weight': weight,
        'sex': sex,
        'allergies': allergies,
        'characterTraits': characterTraits,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static DogModel fromEntity(Dog e) => DogModel(
        id: e.id,
        name: e.name,
        breed: e.breed,
        birthDate: e.birthDate,
        weight: e.weight,
        sex: e.sex?.name,
        allergies: e.allergies,
        characterTraits: e.characterTraits,
        photoUrl: e.photoUrl,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  Dog toEntity() => Dog(
        id: id,
        name: name,
        breed: breed,
        birthDate: birthDate,
        weight: weight,
        sex: sex == 'male' ? DogSex.male : (sex == 'female' ? DogSex.female : null),
        allergies: allergies,
        characterTraits: characterTraits,
        photoUrl: photoUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
