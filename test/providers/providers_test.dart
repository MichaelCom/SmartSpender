import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/providers/budget_provider.dart';
import 'package:smart_spender/providers/category_provider.dart';
import 'package:smart_spender/providers/transaction_provider.dart';

import '../helpers/test_db.dart';

void main() {
  late TestDb env;

  setUp(() {
    env = TestDb.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  group('TransactionProvider', () {
    test('totals and balance derive from loaded transactions', () async {
      final provider = TransactionProvider(env.repositories.transactions);
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
      final provider = TransactionProvider(env.repositories.transactions);
      await provider.addTransaction(makeTransaction(date: DateTime(2024, 1, 1)));
      await provider.addTransaction(makeTransaction(date: DateTime(2024, 6, 1)));
      await provider.addTransaction(makeTransaction(date: DateTime(2024, 3, 1)));

      final dates = provider.transactions.map((t) => t.date).toList();
      expect(dates.first, DateTime(2024, 6, 1));
      expect(dates.last, DateTime(2024, 1, 1));
    });

    test('monthly income and expenses are scoped to the month', () async {
      final provider = TransactionProvider(env.repositories.transactions);
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
      final provider = TransactionProvider(env.repositories.transactions);
      await provider.addTransaction(makeTransaction(description: 'Grocery run'));
      await provider.addTransaction(makeTransaction(description: 'Fuel'));

      expect(provider.searchTransactions('grocery'), hasLength(1));
      expect(provider.searchTransactions(''), hasLength(2));
    });

    test('deleteTransaction removes it from state', () async {
      final provider = TransactionProvider(env.repositories.transactions);
      await provider.addTransaction(makeTransaction());
      final id = provider.transactions.first.id!;

      final ok = await provider.deleteTransaction(id);
      expect(ok, isTrue);
      expect(provider.transactions, isEmpty);
    });

    test('getCategoryExpenseSummary ignores uncategorised transactions',
        () async {
      final provider = TransactionProvider(env.repositories.transactions);
      final catId = await env.repositories.categories.insert(makeCategory());
      await provider.addTransaction(
          makeTransaction(type: 'expense', amount: 50, categoryId: catId));
      await provider.addTransaction(
          makeTransaction(type: 'expense', amount: 30, categoryId: null));

      final summary = provider.getCategoryExpenseSummary();
      expect(summary[catId], 50);
      expect(summary.length, 1);
    });
  });

  group('CategoryProvider', () {
    test('initializeDefaultCategories seeds once', () async {
      final provider = CategoryProvider(env.repositories.categories);
      await provider.loadCategories();
      await provider.initializeDefaultCategories();

      final firstCount = provider.categories.length;
      expect(firstCount, greaterThan(0));
      expect(provider.incomeCategories, isNotEmpty);
      expect(provider.expenseCategories, isNotEmpty);

      await provider.initializeDefaultCategories();
      expect(provider.categories.length, firstCount);
    });

    test('income/expense getters partition the list', () async {
      final provider = CategoryProvider(env.repositories.categories);
      await provider.addCategory(makeCategory(name: 'Salary', type: 'income'));
      await provider.addCategory(makeCategory(name: 'Food', type: 'expense'));

      expect(provider.incomeCategories.map((c) => c.name), ['Salary']);
      expect(provider.expenseCategories.map((c) => c.name), ['Food']);
    });

    test('getCategoryById resolves against the loaded list', () async {
      final provider = CategoryProvider(env.repositories.categories);
      await provider.addCategory(makeCategory(name: 'Food'));
      final id = provider.categories.first.id!;
      expect(provider.getCategoryById(id)!.name, 'Food');
    });
  });

  group('BudgetProvider', () {
    test('calculateEndDate for each period', () {
      final provider = BudgetProvider(env.repositories.budgets);
      final start = DateTime(2024, 6, 1);

      expect(provider.calculateEndDate(start, 'weekly'), DateTime(2024, 6, 8));
      expect(provider.calculateEndDate(start, 'monthly'), DateTime(2024, 6, 30));
      expect(provider.calculateEndDate(start, 'yearly'), DateTime(2025, 5, 31));
    });

    test('hasConflictingBudget detects overlap and respects exclusion',
        () async {
      final provider = BudgetProvider(env.repositories.budgets);
      final catId = await env.repositories.categories.insert(makeCategory());
      await provider.addBudget(makeBudget(
        categoryId: catId,
        startDate: DateTime(2024, 6, 1),
        endDate: DateTime(2024, 6, 30),
      ));

      expect(
        provider.hasConflictingBudget(
            catId, DateTime(2024, 6, 15), DateTime(2024, 7, 15)),
        isTrue,
      );
      expect(
        provider.hasConflictingBudget(
            catId + 999, DateTime(2024, 6, 15), DateTime(2024, 7, 15)),
        isFalse,
      );

      final existingId = provider.budgets.first.id!;
      expect(
        provider.hasConflictingBudget(
          catId,
          DateTime(2024, 6, 15),
          DateTime(2024, 7, 15),
          excludeBudgetKey: existingId,
        ),
        isFalse,
      );
    });

    test('getBudgetSummaryByPeriod aggregates active budgets by period',
        () async {
      final provider = BudgetProvider(env.repositories.budgets);
      final cat1 = await env.repositories.categories.insert(makeCategory(name: 'A'));
      final cat2 = await env.repositories.categories.insert(makeCategory(name: 'B'));
      final now = DateTime.now();

      await provider.addBudget(makeBudget(
        categoryId: cat1,
        amount: 1000,
        period: 'monthly',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 20)),
      ));
      await provider.addBudget(makeBudget(
        categoryId: cat2,
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
      final provider = BudgetProvider(env.repositories.budgets);
      final cat1 = await env.repositories.categories.insert(makeCategory(name: 'A'));
      final cat2 = await env.repositories.categories.insert(makeCategory(name: 'B'));
      await provider.addBudget(makeBudget(categoryId: cat1, amount: 1000));
      await provider.addBudget(makeBudget(categoryId: cat2, amount: 1000));

      final overspent =
          provider.getOverspentBudgets({cat1: 1200, cat2: 800});
      expect(overspent, hasLength(1));
      expect(overspent.first.categoryId, cat1);
    });

    test('getRemainingBudget clamps between 0 and the budget amount', () {
      final provider = BudgetProvider(env.repositories.budgets);
      final budget = makeBudget(amount: 1000);
      expect(provider.getRemainingBudget(budget, 300), 700);
      expect(provider.getRemainingBudget(budget, 1500), 0);
    });
  });
}
