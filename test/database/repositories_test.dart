import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_db.dart';

void main() {
  late TestDb env;

  setUp(() {
    env = TestDb.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  group('Category CRUD', () {
    test('insert then read back', () async {
      final id = await env.repositories.categories.insert(makeCategory(name: 'Food'));
      final loaded = await env.repositories.categories.getById(id);

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Food');
      expect(await env.repositories.categories.getAll(), hasLength(1));
    });

    test('getByType filters correctly', () async {
      await env.repositories.categories.insert(makeCategory(name: 'Salary', type: 'income'));
      await env.repositories.categories.insert(makeCategory(name: 'Rent', type: 'expense'));
      await env.repositories.categories.insert(makeCategory(name: 'Food', type: 'expense'));

      expect(await env.repositories.categories.getByType('income'), hasLength(1));
      expect(await env.repositories.categories.getByType('expense'), hasLength(2));
    });
  });

  group('Category deletion semantics', () {
    test('deleting a category sets its transactions to uncategorised (keeps them)',
        () async {
      final catId = await env.repositories.categories.insert(makeCategory(name: 'Food'));
      await env.repositories.transactions.insert(makeTransaction(categoryId: catId));

      await env.repositories.categories.delete(catId);

      final txns = await env.repositories.transactions.getAllWithCategoryInfo();
      expect(txns, hasLength(1), reason: 'transaction must be kept');
      expect(txns.first.categoryId, isNull, reason: 'category becomes null');
      expect(txns.first.displayCategoryName, 'Uncategorised');
    });

    test('deleting a category cascades to (deletes) its budgets', () async {
      final catId = await env.repositories.categories.insert(makeCategory(name: 'Food'));
      await env.repositories.budgets.insert(makeBudget(categoryId: catId));

      await env.repositories.categories.delete(catId);

      expect(await env.repositories.budgets.getByCategory(catId), isEmpty);
      expect(await env.repositories.budgets.getAllWithCategoryInfo(), isEmpty);
    });
  });

  group('Transaction operations', () {
    test('getByType filters by income/expense', () async {
      await env.repositories.transactions.insert(makeTransaction(type: 'income', amount: 500));
      await env.repositories.transactions.insert(makeTransaction(type: 'expense', amount: 50));
      await env.repositories.transactions.insert(makeTransaction(type: 'expense', amount: 25));

      expect(await env.repositories.transactions.getByType('income'), hasLength(1));
      expect(await env.repositories.transactions.getByType('expense'), hasLength(2));
    });

    test('getByDateRange is inclusive of boundaries', () async {
      await env.repositories.transactions.insert(makeTransaction(date: DateTime(2024, 6, 1)));
      await env.repositories.transactions.insert(makeTransaction(date: DateTime(2024, 6, 15)));
      await env.repositories.transactions.insert(makeTransaction(date: DateTime(2024, 7, 1)));

      final june = await env.repositories.transactions
          .getByDateRange(DateTime(2024, 6, 1), DateTime(2024, 6, 30));
      expect(june, hasLength(2));
    });

    test('getAllWithCategoryInfo joins category fields', () async {
      final catId = await env.repositories.categories.insert(
          makeCategory(name: 'Food', icon: 'restaurant', color: '#FF0000'));
      await env.repositories.transactions.insert(makeTransaction(categoryId: catId));

      final joined = await env.repositories.transactions.getAllWithCategoryInfo();
      expect(joined, hasLength(1));
      expect(joined.first.categoryName, 'Food');
      expect(joined.first.categoryIcon, 'restaurant');
      expect(joined.first.categoryColor, '#FF0000');
    });

    test('uncategorised transactions are still returned by the join', () async {
      await env.repositories.transactions.insert(makeTransaction(categoryId: null));

      final joined = await env.repositories.transactions.getAllWithCategoryInfo();
      expect(joined, hasLength(1));
      expect(joined.first.categoryName, isNull);
    });
  });

  group('Analytics', () {
    test('getTotalIncome and getTotalExpenses sum the right transactions', () async {
      await env.repositories.transactions.insert(makeTransaction(type: 'income', amount: 1000));
      await env.repositories.transactions.insert(makeTransaction(type: 'income', amount: 250));
      await env.repositories.transactions.insert(makeTransaction(type: 'expense', amount: 300));

      expect(await env.repositories.transactions.getTotalIncome(), 1250);
      expect(await env.repositories.transactions.getTotalExpenses(), 300);
    });

    test('getTotalExpenses respects a date range', () async {
      await env.repositories.transactions
          .insert(makeTransaction(type: 'expense', amount: 100, date: DateTime(2024, 6, 10)));
      await env.repositories.transactions
          .insert(makeTransaction(type: 'expense', amount: 200, date: DateTime(2024, 7, 10)));

      final juneOnly = await env.repositories.transactions
          .getTotalExpenses(startDate: DateTime(2024, 6, 1), endDate: DateTime(2024, 6, 30));
      expect(juneOnly, 100);
    });

    test('getExpensesByCategory groups by category name', () async {
      final food = await env.repositories.categories.insert(makeCategory(name: 'Food'));
      final transport = await env.repositories.categories.insert(makeCategory(name: 'Transport'));

      await env.repositories.transactions
          .insert(makeTransaction(type: 'expense', amount: 50, categoryId: food));
      await env.repositories.transactions
          .insert(makeTransaction(type: 'expense', amount: 30, categoryId: food));
      await env.repositories.transactions
          .insert(makeTransaction(type: 'expense', amount: 20, categoryId: transport));

      final byCat = await env.repositories.transactions.getExpensesByCategory();
      expect(byCat['Food'], 80);
      expect(byCat['Transport'], 20);
    });
  });

  group('clearAllData', () {
    test('empties every table', () async {
      final catId = await env.repositories.categories.insert(makeCategory());
      await env.repositories.transactions.insert(makeTransaction(categoryId: catId));
      await env.repositories.budgets.insert(makeBudget(categoryId: catId));

      await env.repositories.clearAllData();

      expect(await env.repositories.categories.getAll(), isEmpty);
      expect(await env.repositories.transactions.getAllWithCategoryInfo(), isEmpty);
      expect(await env.repositories.budgets.getAllWithCategoryInfo(), isEmpty);
    });
  });
}
