import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../repositories/repositories.dart';

/// Generates concrete transactions from recurring rules, catching up any
/// occurrences missed since the rule's [RecurringTransaction.lastGeneratedDate]
/// (or [RecurringTransaction.startDate] if never generated).
class RecurringGenerator {
  RecurringGenerator(this._repositories);

  final AppRepositories _repositories;

  /// For each active rule, create missing [Transaction]s from the day AFTER
  /// [RecurringTransaction.lastGeneratedDate] (or [RecurringTransaction.startDate]
  /// if null) up to and including today (never past [RecurringTransaction.endDate]).
  ///
  /// Each created transaction carries the rule's [recurringId], amount, type,
  /// category and description. The rule's `lastGeneratedDate` is advanced to the
  /// last occurrence actually generated.
  ///
  /// Idempotent: running twice the same day creates nothing new.
  ///
  /// Returns the number of transactions created.
  Future<int> generateDue({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final rules = await _repositories.recurring.getAll();

    var created = 0;
    for (final rule in rules) {
      created += await _generateForRule(rule, today);
    }
    return created;
  }

  Future<int> _generateForRule(
      RecurringTransaction rule, DateTime today) async {
    if (rule.id == null) return 0;

    final start = _dateOnly(rule.startDate);
    // The last occurrence we have already materialised (date-only), or null.
    final lastGenerated =
        rule.lastGeneratedDate == null ? null : _dateOnly(rule.lastGeneratedDate!);

    // The upper bound is today, but never past the rule's end date.
    var upperBound = today;
    if (rule.endDate != null) {
      final end = _dateOnly(rule.endDate!);
      if (end.isBefore(upperBound)) upperBound = end;
    }

    // First occurrence to consider: startDate if never generated, otherwise
    // one period after the last generated occurrence.
    DateTime occurrence;
    if (lastGenerated == null) {
      occurrence = start;
    } else {
      occurrence = _dateOnly(rule.advance(lastGenerated));
    }

    var created = 0;
    DateTime? latest = lastGenerated;
    while (!occurrence.isAfter(upperBound)) {
      // Guard: never before the rule's start.
      if (!occurrence.isBefore(start)) {
        await _repositories.transactions.insert(
          Transaction(
            amount: rule.amount,
            description: rule.description,
            categoryId: rule.categoryId,
            date: occurrence,
            type: rule.type,
            createdAt: DateTime.now(),
            recurringId: rule.id,
          ),
        );
        created++;
        latest = occurrence;
      }
      occurrence = _dateOnly(rule.advance(occurrence));
    }

    if (created > 0 && latest != null) {
      await _repositories.recurring.update(
        rule.copyWith(lastGeneratedDate: latest),
      );
    }

    return created;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
