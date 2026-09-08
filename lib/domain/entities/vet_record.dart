/// Simplified vet record — a generic appointment/reminder (free-text title,
/// no vaccine/antiparasitic/etc. type distinction, no automatic recurrence).
class VetRecord {
  final String id;
  final String title;
  final DateTime date;
  final bool done;
  final String? notes;

  const VetRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.done,
    this.notes,
  });
}

/// Splits a vet record list into the two sections shown in the journal:
/// upcoming (not done, earliest first) and history (done, most recent
/// first). Classification is driven entirely by [VetRecord.done], not by
/// comparing [VetRecord.date] to today — a record keeps its section until
/// someone explicitly marks it done.
class VetJournalSections {
  final List<VetRecord> upcoming;
  final List<VetRecord> history;

  const VetJournalSections({required this.upcoming, required this.history});

  factory VetJournalSections.from(List<VetRecord> records) {
    final upcoming = records.where((r) => !r.done).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final history = records.where((r) => r.done).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return VetJournalSections(upcoming: upcoming, history: history);
  }
}
