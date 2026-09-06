import 'package:equatable/equatable.dart';

import 'collar.dart';

/// Domain entity: dog profile.
class Dog extends Equatable {
  final String id;
  final String name;
  final String? breed;
  final DateTime? birthDate;
  final double? weight;
  final DogSex? sex;
  final List<String> allergies;
  final List<String> characterTraits;
  final String? photoUrl;
  final Collar? collar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Dog({
    required this.id,
    required this.name,
    this.breed,
    this.birthDate,
    this.weight,
    this.sex,
    this.allergies = const [],
    this.characterTraits = const [],
    this.photoUrl,
    this.collar,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    breed,
    birthDate,
    weight,
    sex,
    allergies,
    characterTraits,
    photoUrl,
    collar,
    createdAt,
    updatedAt,
  ];
}

enum DogSex { male, female }
