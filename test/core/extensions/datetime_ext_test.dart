import 'package:flutter_test/flutter_test.dart';
import 'package:k9sync/core/extensions/datetime_ext.dart';

void main() {
  group('DateTimeExt.startOfDay', () {
    test('strips the time-of-day component', () {
      final dt = DateTime(2026, 3, 14, 18, 47, 32, 500);
      final result = dt.startOfDay;
      expect(result, DateTime(2026, 3, 14, 0, 0, 0, 0));
    });

    test('is idempotent on a value already at midnight', () {
      final dt = DateTime(2026, 3, 14);
      expect(dt.startOfDay, dt);
    });
  });

  group('DateTimeExt.endOfDay', () {
    test('sets time to 23:59:59.999', () {
      final dt = DateTime(2026, 3, 14, 9, 0);
      final result = dt.endOfDay;
      expect(result, DateTime(2026, 3, 14, 23, 59, 59, 999));
    });

    test('start and end of the same day are exactly 1 day minus 1ms apart', () {
      final dt = DateTime(2026, 3, 14, 12, 0);
      final diff = dt.endOfDay.difference(dt.startOfDay);
      expect(diff, const Duration(days: 1) - const Duration(milliseconds: 1));
    });
  });

  group('DateTimeExt.toIso8601Utc', () {
    test('converts a local time to a UTC ISO 8601 string', () {
      final dt = DateTime.utc(2026, 3, 14, 10, 30, 0);
      expect(dt.toIso8601Utc(), '2026-03-14T10:30:00.000Z');
    });
  });

  group('DateTimeExt.toApiDateString', () {
    test('formats a typical date as YYYY-MM-DD', () {
      final dt = DateTime(2026, 3, 14);
      expect(dt.toApiDateString(), '2026-03-14');
    });

    test('zero-pads single-digit month and day', () {
      final dt = DateTime(2026, 1, 5);
      expect(dt.toApiDateString(), '2026-01-05');
    });

    test('handles the first day of the year', () {
      final dt = DateTime(2026, 1, 1);
      expect(dt.toApiDateString(), '2026-01-01');
    });

    test('handles the last day of the year', () {
      final dt = DateTime(2026, 12, 31);
      expect(dt.toApiDateString(), '2026-12-31');
    });
  });
}
