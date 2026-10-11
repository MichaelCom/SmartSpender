import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/models/recurring_transaction.dart';

void main() {
  RecurringTransaction make({
    String frequency = 'monthly',
    DateTime? start,
    DateTime? end,
  }) {
    return RecurringTransaction(
      amount: 100,
      description: 'Rent',
      categoryId: null,
      type: 'expense',
      frequency: frequency,
      startDate: start ?? DateTime(2024, 1, 1),
      endDate: end,
      createdAt: start ?? DateTime(2024, 1, 1),
    );
  }

  group('advance', () {
    test('daily adds one day', () {
      final r = make(frequency: 'daily');
      expect(r.advance(DateTime(2024, 1, 1)), DateTime(2024, 1, 2));
    });

    test('weekly adds seven days', () {
      final r = make(frequency: 'weekly');
      expect(r.advance(DateTime(2024, 1, 1)), DateTime(2024, 1, 8));
    });

    test('monthly adds one month', () {
      final r = make(frequency: 'monthly');
      expect(r.advance(DateTime(2024, 1, 15)), DateTime(2024, 2, 15));
    });

    test('yearly adds one year', () {
      final r = make(frequency: 'yearly');
      expect(r.advance(DateTime(2024, 3, 10)), DateTime(2025, 3, 10));
    });
  });

  group('isActive', () {
    test('within window when no end date', () {
      final r = make(start: DateTime(2024, 1, 1));
      expect(r.isActive(DateTime(2024, 6, 1)), isTrue);
    });

    test('false before start', () {
      final r = make(start: DateTime(2024, 1, 1));
      expect(r.isActive(DateTime(2023, 12, 31)), isFalse);
    });

    test('false after end', () {
      final r = make(start: DateTime(2024, 1, 1), end: DateTime(2024, 3, 1));
      expect(r.isActive(DateTime(2024, 4, 1)), isFalse);
    });

    test('true within bounded window', () {
      final r = make(start: DateTime(2024, 1, 1), end: DateTime(2024, 3, 1));
      expect(r.isActive(DateTime(2024, 2, 1)), isTrue);
    });
  });

  group('nextDueDate', () {
    test('returns start when from is before start', () {
      final r = make(frequency: 'monthly', start: DateTime(2024, 6, 1));
      expect(r.nextDueDate(DateTime(2024, 1, 1)), DateTime(2024, 6, 1));
    });

    test('returns next occurrence strictly after from', () {
      final r = make(frequency: 'monthly', start: DateTime(2024, 1, 10));
      // from = Jan 10 -> next is Feb 10
      expect(r.nextDueDate(DateTime(2024, 1, 10)), DateTime(2024, 2, 10));
      // from = Jan 15 -> next is Feb 10
      expect(r.nextDueDate(DateTime(2024, 1, 15)), DateTime(2024, 2, 10));
    });
  });

  test('copyWith overrides selected fields', () {
    final r = make();
    final c = r.copyWith(amount: 250, frequency: 'weekly');
    expect(c.amount, 250);
    expect(c.frequency, 'weekly');
    expect(c.description, r.description);
  });

  test('equality compares persisted fields', () {
    final a = make();
    final b = make();
    expect(a, equals(b));
  });
}
