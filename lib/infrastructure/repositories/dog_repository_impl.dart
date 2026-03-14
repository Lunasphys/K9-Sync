import 'package:dio/dio.dart';

import '../../core/debug/debug_logger.dart';
import '../../domain/entities/dog.dart';
import '../../domain/enums/user_dog_role.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';
import '../../injection.dart';

/// Dog repository — 100% REST (POST /v1/dogs, GET /v1/dogs, etc.)
/// Replaces the Firestore implementation.
class DogRepositoryImpl implements IDogRepository {
  Dio get _dio => getIt<Dio>();

  // ── GET /dogs ───────────────────────────────────────────────────────────────

  @override
  Future<List<Dog>> getDogs() async {
    final response = await _dio.get<List<dynamic>>('/dogs');
    final list = response.data ?? [];
    return list
        .map((e) => _dogFromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── GET /dogs/:dogId ────────────────────────────────────────────────────────

  @override
  Future<Dog?> getDogById(String dogId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/dogs/$dogId');
      return _dogFromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── POST /dogs ──────────────────────────────────────────────────────────────

  @override
  Future<Dog> createDog(CreateDogParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/dogs',
      data: {
        'name': params.name,
        if (params.breed != null) 'breed': params.breed,
        if (params.birthDate != null)
          'birthDate': params.birthDate!.toIso8601String(),
        if (params.weight != null) 'weight': params.weight,
        if (params.sex != null) 'sex': params.sex!.name,
        if (params.allergies.isNotEmpty) 'allergies': params.allergies,
        if (params.photoUrl != null) 'photoUrl': params.photoUrl,
      },
    );
    DebugLogger.log('DOG_REPO', 'Dog created: ${response.data?['id']}');
    return _dogFromJson(response.data!);
  }

  // ── PATCH /dogs/:dogId ──────────────────────────────────────────────────────

  @override
  Future<Dog> updateDog(String dogId, UpdateDogParams params) async {
    final data = <String, dynamic>{};
    if (params.name != null) data['name'] = params.name;
    if (params.breed != null) data['breed'] = params.breed;
    if (params.birthDate != null)
      data['birthDate'] = params.birthDate!.toIso8601String();
    if (params.weight != null) data['weight'] = params.weight;
    if (params.sex != null) data['sex'] = params.sex;
    if (params.allergies != null) data['allergies'] = params.allergies;
    if (params.photoUrl != null) data['photoUrl'] = params.photoUrl;

    final response = await _dio.patch<Map<String, dynamic>>(
      '/dogs/$dogId',
      data: data,
    );
    return _dogFromJson(response.data!);
  }

  // ── DELETE /dogs/:dogId ─────────────────────────────────────────────────────

  @override
  Future<void> deleteDog(String dogId) async {
    await _dio.delete('/dogs/$dogId');
  }

  // ── GET /dogs/:dogId/users ──────────────────────────────────────────────────

  @override
  Future<List<UserDogAccess>> getDogUsers(String dogId) async {
    try {
      final response =
          await _dio.get<List<dynamic>>('/dogs/$dogId/users');
      final list = response.data ?? [];
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return UserDogAccess(
          userId: m['userId'] as String,
          dogId: dogId,
          role: _parseRole(m['role'] as String?),
          canEdit: m['canEdit'] as bool? ?? false,
          expiresAt: m['expiresAt'] != null
              ? DateTime.tryParse(m['expiresAt'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      DebugLogger.log('DOG_REPO', 'getDogUsers failed: $e',
          level: LogLevel.warning);
      return [];
    }
  }

  // ── POST /dogs/:dogId/invite ────────────────────────────────────────────────

  @override
  Future<void> inviteUser(
    String dogId, {
    required String email,
    required UserDogRole role,
  }) async {
    await _dio.post('/dogs/$dogId/invite', data: {
      'email': email,
      'role': role.name,
    });
  }

  // ── DELETE /dogs/:dogId/users/:userId ───────────────────────────────────────

  @override
  Future<void> removeUser(String dogId, String userId) async {
    await _dio.delete('/dogs/$dogId/users/$userId');
  }

  // ── JSON mapper ─────────────────────────────────────────────────────────────

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

  UserDogRole _parseRole(String? raw) {
    if (raw == null) return UserDogRole.family;
    for (final e in UserDogRole.values) {
      if (e.name == raw) return e;
    }
    return UserDogRole.family;
  }
}
