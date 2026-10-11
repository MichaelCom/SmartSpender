import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/models/recurring_transaction.dart';
import 'package:smart_spender/services/recurring_generator.dart';

import '../helpers/test_db.dart';

void main() {
  late TestDb testDb;

  setUp(() {
    testDb = TestDb.create();
  });

  tearDown(() async {
    await testDb.dispose();
  });

  RecurringTransaction rule({
    String frequency = 'monthly',
    required DateTime start,
    DateTime? end,
    DateTime? lastGenerated,
    double amount = 100,
    String type = 'expense',
    int? categoryId,
    String? description = 'Rule',
  }) {
    return RecurringTransaction(
      amount: amount,
      description: description,
      categoryId: categoryId,
      type: type,
      frequency: frequency,
      startDate: start,
      endDate: end,
      lastGeneratedDate: lastGenerated,
      createdAt: start,
    );
  }

  test('generates one tx per missed daily occurrence up to today', () async {
    final now = DateTime(2024, 1, 5);
    final id = await testDb.repositories.recurring.insert(
      rule(frequency: 'daily', start: DateTime(2024, 1, 1)),
    );
    expect(id, greaterThan(0));

    final generator = RecurringGenerator(testDb.repositories);
    final created = await generator.generateDue(now: now);

    // Jan 1,2,3,4,5 = 5 occurrences.
    expect(created, 5);

    final txns = await testDb.repositories.transactions.getAllWithCategoryInfo();
    expect(txns.length, 5);
    expect(txns.every((t) => t.recurringId == id), isTrue);
    expect(txns.every((t) => t.amount == 100), isTrue);
    expect(txns.every((t) => t.type == 'expense'), isTrue);
  });

  test('is idempotent: running twice same day creates nothing new', () async {
    final now = DateTime(2024, 1, 5);
    await testDb.repositories.recurring.insert(
      rule(frequency: 'daily', start: DateTime(2024, 1, 1)),
    );

    final generator = RecurringGenerator(testDb.repositories);
    final first = await generator.generateDue(now: now);
    final second = await generator.generateDue(now: now);

    expect(first, 5);
    expect(second, 0);

    final txns = await testDb.repositories.transactions.getAllWithCategoryInfo();
    expect(txns.length, 5);
  });

  test('continues from lastGeneratedDate on subsequent runs', () async {
    await testDb.repositories.recurring.insert(
      rule(frequency: 'daily', start: DateTime(2024, 1, 1)),
    );
    final generator = RecurringGenerator(testDb.repositories);

    final day3 = await generator.generateDue(now: DateTime(2024, 1, 3));
    expect(day3, 3); // Jan 1,2,3

    final day5 = await generator.generateDue(now: DateTime(2024, 1, 5));
    expect(day5, 2); // Jan 4,5

    final txns = await testDb.repositories.transactions.getAllWithCategoryInfo();
    expect(txns.length, 5);
  });

  test('never generates past endDate', () async {
    await testDb.repositories.recurring.insert(
      rule(
        frequency: 'daily',
        start: DateTime(2024, 1, 1),
        end: DateTime(2024, 1, 3),
      ),
    );
    final generator = RecurringGenerator(testDb.repositories);
    final created = await generator.generateDue(now: DateTime(2024, 1, 10));

    expect(created, 3); // Jan 1,2,3 only
  });

  test('monthly frequency generates one per month', () async {
    await testDb.repositories.recurring.insert(
      rule(frequency: 'monthly', start: DateTime(2024, 1, 15)),
    );
    final generator = RecurringGenerator(testDb.repositories);
    final created = await generator.generateDue(now: DateTime(2024, 4, 20));

    // Jan 15, Feb 15, Mar 15, Apr 15 = 4
    expect(created, 4);
  });

  test('does not generate before startDate', () async {
    await testDb.repositories.recurring.insert(
      rule(frequency: 'daily', start: DateTime(2024, 6, 1)),
    );
    final generator = RecurringGenerator(testDb.repositories);
    final created = await generator.generateDue(now: DateTime(2024, 1, 1));

    expect(created, 0);
  });

  test('updates lastGeneratedDate to the latest occurrence', () async {
    final id = await testDb.repositories.recurring.insert(
      rule(frequency: 'daily', start: DateTime(2024, 1, 1)),
    );
    final generator = RecurringGenerator(testDb.repositories);
    await generator.generateDue(now: DateTime(2024, 1, 5));

    final updated = await testDb.repositories.recurring.getById(id);
    expect(updated, isNotNull);
    expect(updated!.lastGeneratedDate, DateTime(2024, 1, 5));
  });
}
