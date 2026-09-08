import 'package:dio/dio.dart';

import '../../domain/entities/vet_record.dart';
import '../../domain/interfaces/repositories/i_vet_record_repository.dart';
import '../../injection.dart';
import '_error_mapper.dart';

/// Vet record repository — REST (/dogs/:dogId/vet-records).
class VetRecordRepositoryImpl implements IVetRecordRepository {
  Dio get _dio => getIt<Dio>();

  @override
  Future<List<VetRecord>> getVetRecords(String dogId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/dogs/$dogId/vet-records',
      );
      final list = response.data ?? [];
      return list.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw defaultMap(e);
    }
  }

  @override
  Future<VetRecord> createVetRecord(
    String dogId, {
    required String title,
    required DateTime date,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/dogs/$dogId/vet-records',
        data: {
          'title': title,
          'date': date.toIso8601String(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return _fromJson(response.data!);
    } on DioException catch (e) {
      throw defaultMap(e);
    }
  }

  @override
  Future<VetRecord> updateVetRecord(
    String dogId,
    String recordId, {
    String? title,
    DateTime? date,
    bool? done,
    String? notes,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/dogs/$dogId/vet-records/$recordId',
        data: {
          if (title != null) 'title': title,
          if (date != null) 'date': date.toIso8601String(),
          if (done != null) 'done': done,
          if (notes != null) 'notes': notes,
        },
      );
      return _fromJson(response.data!);
    } on DioException catch (e) {
      throw defaultMap(e);
    }
  }

  @override
  Future<void> deleteVetRecord(String dogId, String recordId) async {
    try {
      await _dio.delete('/dogs/$dogId/vet-records/$recordId');
    } on DioException catch (e) {
      throw defaultMap(e);
    }
  }
}

VetRecord _fromJson(Map<String, dynamic> j) {
  return VetRecord(
    id: j['id'] as String,
    title: j['title'] as String,
    date: DateTime.parse(j['date'] as String),
    done: j['done'] as bool? ?? false,
    notes: j['notes'] as String?,
  );
}
