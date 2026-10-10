import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/providers/budget_provider.dart';
import 'package:smart_spender/providers/category_provider.dart';
import 'package:smart_spender/providers/transaction_provider.dart';

import '../helpers/hive_test_env.dart';

void main() {
  late HiveTestEnv env;

  setUp(() async {
    env = await HiveTestEnv.setUp();
  });

  tearDown(() async {
    await env.tearDown();
  });

  group('TransactionProvider', () {
    test('totals and balance derive from loaded transactions', () async {
      final provider = TransactionProvider();
      await provider.addTransaction(makeTransaction(type: 'income', amount: 1000));
      await provider.addTransaction(makeTransaction(type: 'expense', amount: 300));
      await provider.addTransaction(makeTransaction(type: 'expense', amount: 200));

      expect(provider.totalIncome, 1000);
      expect(provider.totalExpenses, 500);
      expect(provider.balance, 500);
      expect(provider.incomeTransactions, hasLength(1));
      expect(provider.expenseTransactions, hasLength(2));
    });

    test('transactions are sorted newest first after load', () async {
      final provider = TransactionProvider();
      await provider.addTransaction(makeTransaction(date: DateTime(2024, 1, 1)));
      await provider.addTransaction(makeTransaction(date: DateTime(2024, 6, 1)));
      await provider.addTransaction(makeTransaction(date: DateTime(2024, 3, 1)));

      final dates = provider.transactions.map((t) => t.date).toList();
      expect(dates.first, DateTime(2024, 6, 1));
      expect(dates.last, DateTime(2024, 1, 1));
    });

    test('monthly income and expenses are scoped to the month', () async {
      final provider = TransactionProvider();
      await provider.addTransaction(
          makeTransaction(type: 'income', amount: 500, date: DateTime(2024, 6, 10)));
      await provider.addTransaction(
          makeTransaction(type: 'expense', amount: 100, date: DateTime(2024, 6, 20)));
      await provider.addTransaction(
          makeTransaction(type: 'expense', amount: 999, date: DateTime(2024, 7, 1)));

      expect(provider.getMonthlyIncome(DateTime(2024, 6)), 500);
      expect(provider.getMonthlyExpenses(DateTime(2024, 6)), 100);
    });

    test('searchTransactions matches description case-insensitively', () async {
      final provider = TransactionProvider();
      await provider.addTransaction(makeTransaction(description: 'Grocery run'));
      await provider.addTransaction(makeTransaction(description: 'Fuel'));

      expect(provider.searchTransactions('grocery'), hasLength(1));
      expect(provider.searchTransactions(''), hasLength(2));
    });

    test('deleteTransaction removes it from state', () async {
      final provider = TransactionProvider();
      await provider.addTransaction(makeTransaction());
      final key = provider.transactions.first.key as int;

      final ok = await provider.deleteTransaction(key);
      expect(ok, isTrue);
      expect(provider.transactions, isEmpty);
    });
  });

  group('CategoryProvider', () {
    test('initializeDefaultCategories seeds once', () async {
      final provider = CategoryProvider();
      await provider.loadCategories();
      await provider.initializeDefaultCategories();

      final firstCount = provider.categories.length;
      expect(firstCount, greaterThan(0));
      expect(provider.incomeCategories, isNotEmpty);
      expect(provider.expenseCategories, isNotEmpty);

      // Running again must not duplicate.
      await provider.initializeDefaultCategories();
      expect(provider.categories.length, firstCount);
    });

    test('income/expense getters partition the list', () async {
      final provider = CategoryProvider();
      await provider.addCategory(makeCategory(name: 'Salary', type: 'income'));
      await provider.addCategory(makeCategory(name: 'Food', type: 'expense'));

      expect(provider.incomeCategories.map((c) => c.name), ['Salary']);
      expect(provider.expenseCategories.map((c) => c.name), ['Food']);
    });
  });

  group('BudgetProvider', () {
    test('calculateEndDate for each period', () {
      final provider = BudgetProvider();
      final start = DateTime(2024, 6, 1);

      expect(provider.calculateEndDate(start, 'weekly'), DateTime(2024, 6, 8));
      expect(provider.calculateEndDate(start, 'monthly'), DateTime(2024, 6, 30));
      expect(provider.calculateEndDate(start, 'yearly'), DateTime(2025, 5, 31));
    });

    test('hasConflictingBudget detects overlap and respects exclusion',
        () async {
      final provider = BudgetProvider();
      await provider.addBudget(makeBudget(
        categoryKey: 1,
        startDate: DateTime(2024, 6, 1),
        endDate: DateTime(2024, 6, 30),
      ));

      // Overlapping window, same category -> conflict.
      expect(
        provider.hasConflictingBudget(
            1, DateTime(2024, 6, 15), DateTime(2024, 7, 15)),
        isTrue,
      );
      // Different category -> no conflict.
      expect(
        provider.hasConflictingBudget(
            2, DateTime(2024, 6, 15), DateTime(2024, 7, 15)),
        isFalse,
      );

      // Excluding the only existing budget removes the conflict.
      final existingKey = provider.budgets.first.key as int;
      expect(
        provider.hasConflictingBudget(
          1,
          DateTime(2024, 6, 15),
          DateTime(2024, 7, 15),
          excludeBudgetKey: existingKey,
        ),
        isFalse,
      );
    });

    test('getBudgetSummaryByPeriod aggregates active budgets by period',
        () async {
      final provider = BudgetProvider();
      final now = DateTime.now();
      // Active monthly budgets.
      await provider.addBudget(makeBudget(
        categoryKey: 1,
        amount: 1000,
        period: 'monthly',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 20)),
      ));
      await provider.addBudget(makeBudget(
        categoryKey: 2,
        amount: 500,
        period: 'monthly',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 20)),
      ));

      final summary = provider.getBudgetSummaryByPeriod();
      expect(summary['monthly'], 1500);
      expect(summary['weekly'], 0);
      expect(summary['yearly'], 0);
    });

    test('getOverspentBudgets returns only exceeded categories', () async {
      final provider = BudgetProvider();
      await provider.addBudget(makeBudget(categoryKey: 1, amount: 1000));
      await provider.addBudget(makeBudget(categoryKey: 2, amount: 1000));

      final overspent =
          provider.getOverspentBudgets({1: 1200, 2: 800});
      expect(overspent, hasLength(1));
      expect(overspent.first.categoryKey, 1);
    });

    test('getRemainingBudget clamps between 0 and the budget amount', () {
      final provider = BudgetProvider();
      final budget = makeBudget(amount: 1000);
      expect(provider.getRemainingBudget(budget, 300), 700);
      expect(provider.getRemainingBudget(budget, 1500), 0);
    });
  });
}
