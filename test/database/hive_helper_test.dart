import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/database/hive_helper.dart';

import '../helpers/hive_test_env.dart';

void main() {
  late HiveTestEnv env;

  setUp(() async {
    env = await HiveTestEnv.setUp();
  });

  tearDown(() async {
    await env.tearDown();
  });

  group('Category CRUD', () {
    test('insert then read back', () async {
      final key = await HiveHelper.insertCategory(makeCategory(name: 'Food'));
      final loaded = HiveHelper.getCategory(key);

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Food');
      expect(HiveHelper.getAllCategories(), hasLength(1));
    });

    test('getCategoriesByType filters correctly', () async {
      await HiveHelper.insertCategory(makeCategory(name: 'Salary', type: 'income'));
      await HiveHelper.insertCategory(makeCategory(name: 'Rent', type: 'expense'));
      await HiveHelper.insertCategory(makeCategory(name: 'Food', type: 'expense'));

      expect(HiveHelper.getCategoriesByType('income'), hasLength(1));
      expect(HiveHelper.getCategoriesByType('expense'), hasLength(2));
    });

    test('deleting a category cascades to its transactions and budgets',
        () async {
      final catKey = await HiveHelper.insertCategory(makeCategory(name: 'Food'));
      await HiveHelper.insertTransaction(makeTransaction(categoryKey: catKey));
      await HiveHelper.insertBudget(makeBudget(categoryKey: catKey));

      // A transaction under a different category should survive.
      final otherCat = await HiveHelper.insertCategory(makeCategory(name: 'Other'));
      await HiveHelper.insertTransaction(makeTransaction(categoryKey: otherCat));

      await HiveHelper.deleteCategory(catKey);

      expect(HiveHelper.getCategory(catKey), isNull);
      expect(HiveHelper.getTransactionsByCategory(catKey), isEmpty);
      expect(HiveHelper.getBudgetsByCategory(catKey), isEmpty);
      expect(HiveHelper.getTransactionsByCategory(otherCat), hasLength(1));
    });
  });

  group('Transaction operations', () {
    test('getTransactionsByType filters by income/expense', () async {
      await HiveHelper.insertTransaction(makeTransaction(type: 'income', amount: 500));
      await HiveHelper.insertTransaction(makeTransaction(type: 'expense', amount: 50));
      await HiveHelper.insertTransaction(makeTransaction(type: 'expense', amount: 25));

      expect(HiveHelper.getTransactionsByType('income'), hasLength(1));
      expect(HiveHelper.getTransactionsByType('expense'), hasLength(2));
    });

    test('getTransactionsByDateRange is inclusive of boundaries', () async {
      await HiveHelper.insertTransaction(
          makeTransaction(date: DateTime(2024, 6, 1)));
      await HiveHelper.insertTransaction(
          makeTransaction(date: DateTime(2024, 6, 15)));
      await HiveHelper.insertTransaction(
          makeTransaction(date: DateTime(2024, 7, 1)));

      final june = HiveHelper.getTransactionsByDateRange(
        DateTime(2024, 6, 1),
        DateTime(2024, 6, 30),
      );
      expect(june, hasLength(2));
    });

    test('getTransactionsWithCategoryInfo joins category fields', () async {
      final catKey = await HiveHelper.insertCategory(
          makeCategory(name: 'Food', icon: 'restaurant', color: '#FF0000'));
      await HiveHelper.insertTransaction(makeTransaction(categoryKey: catKey));

      final joined = HiveHelper.getTransactionsWithCategoryInfo();
      expect(joined, hasLength(1));
      expect(joined.first.categoryName, 'Food');
      expect(joined.first.categoryIcon, 'restaurant');
      expect(joined.first.categoryColor, '#FF0000');
    });
  });

  group('Analytics', () {
    test('getTotalIncome and getTotalExpenses sum the right transactions',
        () async {
      await HiveHelper.insertTransaction(makeTransaction(type: 'income', amount: 1000));
      await HiveHelper.insertTransaction(makeTransaction(type: 'income', amount: 250));
      await HiveHelper.insertTransaction(makeTransaction(type: 'expense', amount: 300));

      expect(HiveHelper.getTotalIncome(), 1250);
      expect(HiveHelper.getTotalExpenses(), 300);
    });

    test('getTotalExpenses respects a date range', () async {
      await HiveHelper.insertTransaction(
          makeTransaction(type: 'expense', amount: 100, date: DateTime(2024, 6, 10)));
      await HiveHelper.insertTransaction(
          makeTransaction(type: 'expense', amount: 200, date: DateTime(2024, 7, 10)));

      final juneOnly = HiveHelper.getTotalExpenses(
        startDate: DateTime(2024, 6, 1),
        endDate: DateTime(2024, 6, 30),
      );
      expect(juneOnly, 100);
    });

    test('getExpensesByCategory groups by category name', () async {
      final food = await HiveHelper.insertCategory(makeCategory(name: 'Food'));
      final transport =
          await HiveHelper.insertCategory(makeCategory(name: 'Transport'));

      await HiveHelper.insertTransaction(
          makeTransaction(type: 'expense', amount: 50, categoryKey: food));
      await HiveHelper.insertTransaction(
          makeTransaction(type: 'expense', amount: 30, categoryKey: food));
      await HiveHelper.insertTransaction(
          makeTransaction(type: 'expense', amount: 20, categoryKey: transport));

      final byCat = HiveHelper.getExpensesByCategory();
      expect(byCat['Food'], 80);
      expect(byCat['Transport'], 20);
    });
  });

  group('clearAllData', () {
    test('empties every box', () async {
      await HiveHelper.insertCategory(makeCategory());
      await HiveHelper.insertTransaction(makeTransaction());
      await HiveHelper.insertBudget(makeBudget());

      await HiveHelper.clearAllData();

      expect(HiveHelper.getAllCategories(), isEmpty);
      expect(HiveHelper.getAllTransactions(), isEmpty);
      expect(HiveHelper.getAllBudgets(), isEmpty);
    });
  });
}
