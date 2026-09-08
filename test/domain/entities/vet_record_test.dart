import 'package:flutter_test/flutter_test.dart';
import 'package:k9sync/domain/entities/vet_record.dart';

VetRecord _record(String id, DateTime date, bool done) => VetRecord(
  id: id,
  title: 'Record $id',
  date: date,
  done: done,
);

void main() {
  group('VetJournalSections.from', () {
    test('splits records into upcoming (not done) and history (done)', () {
      final upcoming = _record('u1', DateTime(2026, 6, 1), false);
      final past = _record('p1', DateTime(2026, 1, 1), true);

      final sections = VetJournalSections.from([upcoming, past]);

      expect(sections.upcoming.map((r) => r.id), ['u1']);
      expect(sections.history.map((r) => r.id), ['p1']);
    });

    test('sorts upcoming entries earliest date first', () {
      final later = _record('later', DateTime(2026, 12, 1), false);
      final sooner = _record('sooner', DateTime(2026, 3, 1), false);

      final sections = VetJournalSections.from([later, sooner]);

      expect(sections.upcoming.map((r) => r.id), ['sooner', 'later']);
    });

    test('sorts history entries most recent date first', () {
      final older = _record('older', DateTime(2025, 1, 1), true);
      final newer = _record('newer', DateTime(2026, 1, 1), true);

      final sections = VetJournalSections.from([older, newer]);

      expect(sections.history.map((r) => r.id), ['newer', 'older']);
    });

    test('classification follows done, not whether the date is in the past', () {
      // A past-dated entry not yet marked done stays "upcoming" — done is
      // the only signal, per the vet journal's design (no auto-recurrence,
      // no reliance on date comparison to classify).
      final overdueButNotDone = _record(
        'overdue',
        DateTime(2020, 1, 1),
        false,
      );
      final futureButDone = _record('future-done', DateTime(2030, 1, 1), true);

      final sections = VetJournalSections.from([
        overdueButNotDone,
        futureButDone,
      ]);

      expect(sections.upcoming.map((r) => r.id), ['overdue']);
      expect(sections.history.map((r) => r.id), ['future-done']);
    });

    test('returns empty sections for an empty record list', () {
      final sections = VetJournalSections.from(const []);

      expect(sections.upcoming, isEmpty);
      expect(sections.history, isEmpty);
    });
  });
}
