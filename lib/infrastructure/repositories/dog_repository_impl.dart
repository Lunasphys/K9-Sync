import 'package:dio/dio.dart';

import '../../core/debug/debug_logger.dart';
import '../../domain/entities/collar.dart';
import '../../domain/entities/dog.dart';
import '../../domain/entities/geofence.dart';
import '../../domain/enums/user_dog_role.dart';
import '../../domain/interfaces/repositories/i_dog_repository.dart';
import '../../injection.dart';
import '_error_mapper.dart';

/// Dog repository — 100% REST (POST /v1/dogs, GET /v1/dogs, etc.)
/// Replaces the Firestore implementation.
class DogRepositoryImpl implements IDogRepository {
  Dio get _dio => getIt<Dio>();

  // ── GET /dogs ───────────────────────────────────────────────────────────────

  @override
  Future<List<Dog>> getDogs() async {
    final response = await _dio.get<List<dynamic>>('/dogs');
    final list = response.data ?? [];
    return list.map((e) => _dogFromJson(e as Map<String, dynamic>)).toList();
  }

  // ── GET /dogs/:dogId ────────────────────────────────────────────────────────

  @override
  Future<Dog?> getDogById(String dogId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/dogs/$dogId');
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
      final response = await _dio.get<List<dynamic>>('/dogs/$dogId/users');
      final list = response.data ?? [];
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return UserDogAccess(
          userId: m['userId'] as String,
          dogId: dogId,
          email: m['email'] as String,
          firstName: m['firstName'] as String,
          lastName: m['lastName'] as String,
          role: _parseRole(m['role'] as String?),
          expiresAt: m['expiresAt'] != null
              ? DateTime.tryParse(m['expiresAt'] as String)
              : null,
        );
      }).toList();
    } on DioException catch (e) {
      DebugLogger.log(
        'DOG_REPO',
        'getDogUsers failed: $e',
        level: LogLevel.warning,
      );
      throw defaultMap(e);
    }
  }

  // ── POST /dogs/:dogId/invite ────────────────────────────────────────────────

  @override
  Future<InviteOutcome> inviteUser(
    String dogId, {
    required String email,
    required UserDogRole role,
    DateTime? expiresAt,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/dogs/$dogId/invite',
        data: {
          'email': email,
          'role': role.value,
          // See vet_record_repository_impl.dart — the backend's zod schema
          // requires a strict UTC datetime (trailing Z); a local DateTime's
          // toIso8601String() omits it and gets rejected as "Invalid
          // request body".
          if (expiresAt != null)
            'expiresAt': expiresAt.toUtc().toIso8601String(),
        },
      );
      final status = response.data?['status'] as String?;
      return status == 'granted' ? InviteOutcome.granted : InviteOutcome.pending;
    } on DioException catch (e) {
      throw defaultMap(e);
    }
  }

  // ── DELETE /dogs/:dogId/users/:userId ───────────────────────────────────────

  @override
  Future<void> removeUser(String dogId, String userId) async {
    try {
      await _dio.delete('/dogs/$dogId/users/$userId');
    } on DioException catch (e) {
      throw defaultMap(e);
    }
  }

  // ── POST /dogs/:dogId/collar/pair ───────────────────────────────────────────

  @override
  Future<Collar> pairCollar(String dogId, {required String serialNumber}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/dogs/$dogId/collar/pair',
        data: {'serialNumber': serialNumber},
      );
      return _collarFromJson(response.data!);
    } on DioException catch (e) {
      throw defaultMap(e);
    }
  }

  // ── PUT /dogs/:dogId/geofence ────────────────────────────────────────────────

  @override
  Future<Geofence> upsertGeofence(
    String dogId, {
    required double latitude,
    required double longitude,
    required int radiusM,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/dogs/$dogId/geofence',
        data: {'latitude': latitude, 'longitude': longitude, 'radiusM': radiusM},
      );
      return _geofenceFromJson(response.data!);
    } on DioException catch (e) {
      throw defaultMap(e);
    }
  }

  // ── DELETE /dogs/:dogId/geofence ─────────────────────────────────────────────

  @override
  Future<void> deleteGeofence(String dogId) async {
    try {
      await _dio.delete('/dogs/$dogId/geofence');
    } on DioException catch (e) {
      throw defaultMap(e);
    }
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
      allergies:
          (j['allergies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      characterTraits:
          (j['characterTraits'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      photoUrl: j['photoUrl'] as String?,
      collar: j['collar'] != null
          ? _collarFromJson(j['collar'] as Map<String, dynamic>)
          : null,
      geofenceZone: j['geofenceZone'] != null
          ? _geofenceFromJson(j['geofenceZone'] as Map<String, dynamic>)
          : null,
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Collar _collarFromJson(Map<String, dynamic> j) {
    return Collar(
      id: j['id'] as String,
      dogId: j['dogId'] as String?,
      serialNumber: j['serialNumber'] as String,
      batteryLevel: j['batteryLevel'] as int?,
      firmwareVersion: j['firmwareVersion'] as String?,
      isOnline: j['isOnline'] as bool? ?? false,
      lastSeenAt: j['lastSeenAt'] != null
          ? DateTime.tryParse(j['lastSeenAt'] as String)
          : null,
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: j['updatedAt'] != null
          ? DateTime.tryParse(j['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Geofence _geofenceFromJson(Map<String, dynamic> j) {
    return Geofence(
      id: j['id'] as String,
      dogId: j['dogId'] as String,
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      radiusM: (j['radiusM'] as num).toInt(),
      isInside: j['isInside'] as bool? ?? true,
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
      if (e.value == raw) return e;
    }
    return UserDogRole.family;
  }
}
