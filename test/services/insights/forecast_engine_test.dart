import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/models/budget.dart';
import 'package:smart_spender/models/recurring_transaction.dart';
import 'package:smart_spender/models/transaction.dart';
import 'package:smart_spender/services/insights/forecast_engine.dart';

Budget _budget(int categoryId, double amount) => Budget(
      id: 1,
      categoryId: categoryId,
      amount: amount,
      period: 'monthly',
      startDate: DateTime(2024, 6, 1),
      endDate: DateTime(2024, 6, 30),
      createdAt: DateTime(2024, 6, 1),
    );

Transaction _tx(double amount, DateTime date,
        {int categoryId = 1, String type = 'expense', int? recurringId}) =>
    Transaction(
      amount: amount,
      description: 'tx',
      categoryId: categoryId,
      date: date,
      type: type,
      createdAt: date,
      recurringId: recurringId,
    );

void main() {
  // Pretend "today" is June 10 (10 of 30 days elapsed, 20 remaining).
  final now = DateTime(2024, 6, 10);

  group('forecastBudget', () {
    test('simple run-rate on discretionary spend', () {
      // R500 discretionary over 10 days -> R50/day -> +R1000 for 20 remaining.
      final txs = [_tx(500, DateTime(2024, 6, 5))];
      final f = ForecastEngine.forecastBudget(
        budget: _budget(1, 2000),
        monthTransactions: txs,
        recurring: const [],
        now: now,
      );
      expect(f.spentSoFar, 500);
      expect(f.projectedDiscretionary, closeTo(1000, 0.001));
      expect(f.projectedTotal, closeTo(1500, 0.001));
      expect(f.projectedToExceed, isFalse);
    });

    test('recurring spend is counted exactly, not run-rated', () {
      // R500 of spend so far was recurring (rent on day 1); run-rate should NOT
      // smear it. A monthly rule means no FURTHER occurrence this month.
      final txs = [_tx(500, DateTime(2024, 6, 1), recurringId: 7)];
      final rule = RecurringTransaction(
        id: 7,
        amount: 500,
        categoryId: 1,
        type: 'expense',
        frequency: 'monthly',
        startDate: DateTime(2024, 6, 1),
        createdAt: DateTime(2024, 6, 1),
      );
      final f = ForecastEngine.forecastBudget(
        budget: _budget(1, 2000),
        monthTransactions: txs,
        recurring: [rule],
        now: now,
      );
      // Discretionary so-far is 0 -> projectedDiscretionary 0.
      expect(f.projectedDiscretionary, 0);
      // No further monthly occurrence before month end.
      expect(f.remainingRecurring, 0);
      expect(f.projectedTotal, closeTo(500, 0.001));
    });

    test('adds remaining recurring occurrences before month end', () {
      // A weekly R100 rule starting June 1: occurrences on 1,8,15,22,29.
      // "today" is June 10 -> remaining this month: 15, 22, 29 = 3 * 100 = 300.
      final rule = RecurringTransaction(
        id: 7,
        amount: 100,
        categoryId: 1,
        type: 'expense',
        frequency: 'weekly',
        startDate: DateTime(2024, 6, 1),
        createdAt: DateTime(2024, 6, 1),
      );
      final f = ForecastEngine.forecastBudget(
        budget: _budget(1, 1000),
        monthTransactions: const [],
        recurring: [rule],
        now: now,
      );
      expect(f.remainingRecurring, closeTo(300, 0.001));
    });

    test('flags projected overspend', () {
      // R900 discretionary in 10 days -> R90/day -> +R1800 -> R2700 total > 2000.
      final txs = [_tx(900, DateTime(2024, 6, 5))];
      final f = ForecastEngine.forecastBudget(
        budget: _budget(1, 2000),
        monthTransactions: txs,
        recurring: const [],
        now: now,
      );
      expect(f.projectedToExceed, isTrue);
      expect(f.projectedOverBy, greaterThan(0));
    });
  });

  group('forecastMonth', () {
    test('projects income and expenses with run-rate', () {
      final txs = [
        _tx(1000, DateTime(2024, 6, 2), type: 'income'),
        _tx(300, DateTime(2024, 6, 3), type: 'expense'),
      ];
      final f = ForecastEngine.forecastMonth(
        monthTransactions: txs,
        recurring: const [],
        now: now,
      );
      expect(f.incomeSoFar, 1000);
      expect(f.expensesSoFar, 300);
      // income: 1000 + (1000/10)*20 = 3000; expense: 300 + (300/10)*20 = 900.
      expect(f.projectedIncome, closeTo(3000, 0.001));
      expect(f.projectedExpenses, closeTo(900, 0.001));
      expect(f.projectedNet, closeTo(2100, 0.001));
    });
  });
}
