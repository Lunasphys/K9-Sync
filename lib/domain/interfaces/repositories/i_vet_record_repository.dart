import '../../entities/vet_record.dart';

/// Contract for the vet record book (Clean Architecture — domain).
/// Owner and family can manage it; a dog_sitter has read-only access
/// (enforced server-side — see requireDogAccess's excludeDogSitter option).
abstract interface class IVetRecordRepository {
  Future<List<VetRecord>> getVetRecords(String dogId);

  Future<VetRecord> createVetRecord(
    String dogId, {
    required String title,
    required DateTime date,
    String? notes,
  });

  Future<VetRecord> updateVetRecord(
    String dogId,
    String recordId, {
    String? title,
    DateTime? date,
    bool? done,
    String? notes,
  });

  Future<void> deleteVetRecord(String dogId, String recordId);
}
