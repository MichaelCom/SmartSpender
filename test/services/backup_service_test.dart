import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/models/budget.dart';
import 'package:smart_spender/models/category.dart';
import 'package:smart_spender/models/recurring_transaction.dart';
import 'package:smart_spender/models/transaction.dart';
import 'package:smart_spender/services/backup_service.dart';

import '../helpers/test_db.dart';

void main() {
  late TestDb testDb;
  late BackupService service;

  setUp(() {
    testDb = TestDb.create();
    service = BackupService(testDb.repositories);
  });

  tearDown(() async {
    await testDb.dispose();
  });

  // Helper: seed a known data set and return the inserted category ids.
  Future<({int foodId, int salaryId})> seedData() async {
    final foodId = await testDb.repositories.categories.insert(
      makeCategory(name: 'Food & Dining', type: 'expense', color: '#F44336'),
    );
    final salaryId = await testDb.repositories.categories.insert(
      makeCategory(name: 'Salary', type: 'income', color: '#4CAF50'),
    );

    await testDb.repositories.transactions.insert(
      makeTransaction(
        amount: 12.50,
        description: 'Lunch',
        categoryId: foodId,
        type: 'expense',
        date: DateTime(2026, 1, 10),
      ),
    );
    await testDb.repositories.transactions.insert(
      makeTransaction(
        amount: 3000.0,
        description: 'Paycheck',
        categoryId: salaryId,
        type: 'income',
        date: DateTime(2026, 1, 1),
      ),
    );
    // Uncategorised transaction.
    await testDb.repositories.transactions.insert(
      makeTransaction(
        amount: 5.0,
        description: 'Mystery',
        categoryId: null,
        type: 'expense',
        date: DateTime(2026, 1, 5),
      ),
    );

    await testDb.repositories.budgets.insert(
      makeBudget(
        categoryId: foodId,
        amount: 400.0,
        period: 'monthly',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      ),
    );

    return (foodId: foodId, salaryId: salaryId);
  }

  group('exportToJsonString', () {
    test('produces valid schema v2 JSON with all data', () async {
      await seedData();
      final jsonStr = await service.exportToJsonString();
      final map = json.decode(jsonStr) as Map<String, dynamic>;

      expect(map['schemaVersion'], 2);
      expect(map['app'], 'SmartSpender');
      expect(map['exportedAt'], isA<String>());
      expect((map['categories'] as List).length, 2);
      expect((map['transactions'] as List).length, 3);
      expect((map['budgets'] as List).length, 1);
      expect(map['recurring'], isA<List>());
    });
  });

  group('parseJson', () {
    test('rejects malformed JSON', () {
      expect(
        () => service.parseJson('{not valid json'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects non-object root', () {
      expect(
        () => service.parseJson('[1,2,3]'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects missing schemaVersion', () {
      final jsonStr = json.encode({
        'categories': [],
        'transactions': [],
        'budgets': [],
      });
      expect(
        () => service.parseJson(jsonStr),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects unsupported schemaVersion', () {
      final jsonStr = json.encode({
        'schemaVersion': 99,
        'categories': [],
        'transactions': [],
        'budgets': [],
      });
      expect(
        () => service.parseJson(jsonStr),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('accepts a v1 backup (no recurring array)', () {
      final jsonStr = json.encode({
        'schemaVersion': 1,
        'categories': [],
        'transactions': [],
        'budgets': [],
      });
      final data = service.parseJson(jsonStr);
      expect(data.recurring, isEmpty);
    });

    test('rejects non-list categories', () {
      final jsonStr = json.encode({
        'schemaVersion': 1,
        'categories': {'not': 'a list'},
        'transactions': [],
        'budgets': [],
      });
      expect(
        () => service.parseJson(jsonStr),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('rejects non-list transactions', () {
      final jsonStr = json.encode({
        'schemaVersion': 1,
        'categories': [],
        'transactions': 'nope',
        'budgets': [],
      });
      expect(
        () => service.parseJson(jsonStr),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('parses a well-formed backup into domain models', () async {
      await seedData();
      final jsonStr = await service.exportToJsonString();
      final data = service.parseJson(jsonStr);

      expect(data.categories, hasLength(2));
      expect(data.transactions, hasLength(3));
      expect(data.budgets, hasLength(1));
      expect(
        data.categories.map((c) => c.name),
        containsAll(<String>['Food & Dining', 'Salary']),
      );
    });
  });

  group('restoreFromJson round-trip', () {
    test('exports then restores identical data into a fresh DB', () async {
      await seedData();
      final jsonStr = await service.exportToJsonString();

      // Fresh DB + service.
      final freshDb = TestDb.create();
      addTearDown(freshDb.dispose);
      final freshService = BackupService(freshDb.repositories);

      final result = await freshService.restoreFromJson(jsonStr);

      expect(result.success, isTrue);
      expect(result.categoriesImported, 2);
      expect(result.transactionsImported, 3);
      expect(result.budgetsImported, 1);

      final cats = await freshDb.repositories.categories.getAll();
      final txns =
          await freshDb.repositories.transactions.getAllWithCategoryInfo();
      final budgets =
          await freshDb.repositories.budgets.getAllWithCategoryInfo();

      expect(cats, hasLength(2));
      expect(txns, hasLength(3));
      expect(budgets, hasLength(1));

      // Values preserved (ignoring ids).
      final lunch = txns.firstWhere((t) => t.description == 'Lunch');
      expect(lunch.amount, 12.50);
      expect(lunch.type, 'expense');
      expect(lunch.categoryName, 'Food & Dining');
    });

    test('remaps category ids so relationships survive new auto-increment ids',
        () async {
      // Build a backup where old ids will NOT match fresh ones. We insert an
      // extra category in the fresh DB first so the auto-increment counter is
      // offset, then clear + restore and confirm links still resolve.
      await seedData();
      final jsonStr = await service.exportToJsonString();

      final freshDb = TestDb.create();
      addTearDown(freshDb.dispose);
      // Insert + delete a few to bump the sequence away from the old ids.
      for (var i = 0; i < 5; i++) {
        await freshDb.repositories.categories.insert(makeCategory(name: 'x$i'));
      }
      final freshService = BackupService(freshDb.repositories);

      final result = await freshService.restoreFromJson(jsonStr);
      expect(result.success, isTrue);

      final txns =
          await freshDb.repositories.transactions.getAllWithCategoryInfo();
      final budgets =
          await freshDb.repositories.budgets.getAllWithCategoryInfo();

      // The Food transaction and the budget must still point at the Food cat.
      final lunch = txns.firstWhere((t) => t.description == 'Lunch');
      expect(lunch.categoryName, 'Food & Dining');
      expect(lunch.categoryId, isNotNull);

      expect(budgets.single.categoryName, 'Food & Dining');
      // The budget's categoryId must equal the restored Food category's id.
      final cats = await freshDb.repositories.categories.getAll();
      final foodId = cats.firstWhere((c) => c.name == 'Food & Dining').id;
      expect(budgets.single.categoryId, foodId);
      expect(lunch.categoryId, foodId);
    });

    test('uncategorised transaction survives round-trip as null category',
        () async {
      await seedData();
      final jsonStr = await service.exportToJsonString();

      final freshDb = TestDb.create();
      addTearDown(freshDb.dispose);
      final freshService = BackupService(freshDb.repositories);
      await freshService.restoreFromJson(jsonStr);

      final txns =
          await freshDb.repositories.transactions.getAllWithCategoryInfo();
      final mystery = txns.firstWhere((t) => t.description == 'Mystery');
      expect(mystery.categoryId, isNull);
      expect(mystery.categoryName, isNull);
    });

    test('restore REPLACES existing data rather than merging', () async {
      // Seed source DB and export.
      await seedData();
      final jsonStr = await service.exportToJsonString();

      // Target DB has its own unrelated data.
      final targetDb = TestDb.create();
      addTearDown(targetDb.dispose);
      final preId = await targetDb.repositories.categories.insert(
        makeCategory(name: 'PRE-EXISTING', type: 'expense'),
      );
      await targetDb.repositories.transactions.insert(
        makeTransaction(description: 'old tx', categoryId: preId),
      );

      final targetService = BackupService(targetDb.repositories);
      await targetService.restoreFromJson(jsonStr);

      final cats = await targetDb.repositories.categories.getAll();
      final txns =
          await targetDb.repositories.transactions.getAllWithCategoryInfo();

      // Pre-existing data must be gone.
      expect(cats.any((c) => c.name == 'PRE-EXISTING'), isFalse);
      expect(txns.any((t) => t.description == 'old tx'), isFalse);
      // Only the backup's data remains.
      expect(cats, hasLength(2));
      expect(txns, hasLength(3));
    });

    test('transaction with unknown categoryId imports as uncategorised',
        () async {
      // Hand-craft a backup referencing a categoryId that has no category.
      final jsonStr = json.encode({
        'schemaVersion': 1,
        'app': 'SmartSpender',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'categories': [
          {
            'id': 1,
            'name': 'Food',
            'type': 'expense',
            'color': '#F44336',
            'icon': 'restaurant',
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
          }
        ],
        'transactions': [
          {
            'id': 10,
            'amount': 9.99,
            'description': 'Orphan',
            'categoryId': 999, // unknown
            'date': DateTime(2026, 1, 2).toIso8601String(),
            'type': 'expense',
            'createdAt': DateTime(2026, 1, 2).toIso8601String(),
          }
        ],
        'budgets': [],
      });

      final result = await service.restoreFromJson(jsonStr);
      expect(result.success, isTrue);
      expect(result.transactionsImported, 1);

      final txns =
          await testDb.repositories.transactions.getAllWithCategoryInfo();
      final orphan = txns.firstWhere((t) => t.description == 'Orphan');
      expect(orphan.categoryId, isNull);
    });

    test('bad JSON passed to restoreFromJson returns failure, no DB change',
        () async {
      await seedData();
      final before =
          await testDb.repositories.transactions.getAllWithCategoryInfo();

      final result = await service.restoreFromJson('{broken');
      expect(result.success, isFalse);

      final after =
          await testDb.repositories.transactions.getAllWithCategoryInfo();
      // DB untouched because parse failed before clearAllData.
      expect(after.length, before.length);
    });
  });

  group('exportTransactionsToCsvString', () {
    test('emits the required header row', () async {
      final csv = await service.exportTransactionsToCsvString();
      final firstLine = csv.split('\r\n').first;
      expect(firstLine, 'date,type,amount,category,description');
    });

    test('formats a plain row correctly', () async {
      final catId = await testDb.repositories.categories.insert(
        makeCategory(name: 'Food', type: 'expense'),
      );
      await testDb.repositories.transactions.insert(
        makeTransaction(
          amount: 12.5,
          description: 'Lunch',
          categoryId: catId,
          type: 'expense',
          date: DateTime(2026, 1, 10),
        ),
      );

      final csv = await service.exportTransactionsToCsvString();
      final lines = csv.trim().split('\r\n');
      expect(lines, hasLength(2));
      expect(lines[1], '2026-01-10,expense,12.50,Food,Lunch');
    });

    test('quotes descriptions containing a comma (RFC-4180)', () async {
      await testDb.repositories.transactions.insert(
        makeTransaction(
          amount: 20.0,
          description: 'Coffee, tea, and cake',
          categoryId: null,
          type: 'expense',
          date: DateTime(2026, 2, 3),
        ),
      );

      final csv = await service.exportTransactionsToCsvString();
      final lines = csv.trim().split('\r\n');
      expect(lines[1], contains('"Coffee, tea, and cake"'));
      // Uncategorised => empty category field.
      expect(lines[1], '2026-02-03,expense,20.00,,"Coffee, tea, and cake"');
    });

    test('escapes embedded double quotes by doubling them', () async {
      await testDb.repositories.transactions.insert(
        makeTransaction(
          amount: 1.0,
          description: 'He said "hi"',
          categoryId: null,
          type: 'expense',
          date: DateTime(2026, 2, 4),
        ),
      );

      final csv = await service.exportTransactionsToCsvString();
      final lines = csv.trim().split('\r\n');
      expect(lines[1], contains('"He said ""hi"""'));
    });

    test('quotes descriptions containing a newline', () async {
      await testDb.repositories.transactions.insert(
        makeTransaction(
          amount: 1.0,
          description: 'line1\nline2',
          categoryId: null,
          type: 'expense',
          date: DateTime(2026, 2, 5),
        ),
      );

      final csv = await service.exportTransactionsToCsvString();
      // The quoted field preserves the embedded newline.
      expect(csv, contains('"line1\nline2"'));
    });
  });

  group('recurring round-trip (v2)', () {
    test('exports recurring rules and restores them with remapped category',
        () async {
      final ids = await seedData();
      // A monthly recurring expense tied to the Food category.
      await testDb.repositories.recurring.insert(
        RecurringTransaction(
          amount: 199.0,
          description: 'Streaming subscription',
          categoryId: ids.foodId,
          type: 'expense',
          frequency: 'monthly',
          startDate: DateTime(2026, 1, 1),
          endDate: null,
          lastGeneratedDate: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      // An uncategorised recurring income (categoryId null).
      await testDb.repositories.recurring.insert(
        RecurringTransaction(
          amount: 50.0,
          description: 'Odd job',
          categoryId: null,
          type: 'income',
          frequency: 'weekly',
          startDate: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      final jsonStr = await service.exportToJsonString();
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      expect((map['recurring'] as List).length, 2);

      // Restore into a fresh DB (new ids assigned).
      final fresh = TestDb.create();
      addTearDown(fresh.dispose);
      final freshService = BackupService(fresh.repositories);
      final result = await freshService.restoreFromJson(jsonStr);

      expect(result.success, isTrue);
      expect(result.recurringImported, 2);

      final restored = await fresh.repositories.recurring.getAll();
      expect(restored, hasLength(2));

      // The categorised rule must point at the Food category under its NEW id.
      final foodCat = (await fresh.repositories.categories.getAll())
          .firstWhere((c) => c.name == 'Food & Dining');
      final sub = restored.firstWhere((r) => r.description == 'Streaming subscription');
      expect(sub.categoryId, foodCat.id);
      expect(sub.frequency, 'monthly');

      // The uncategorised rule stays null.
      final odd = restored.firstWhere((r) => r.description == 'Odd job');
      expect(odd.categoryId, isNull);
    });

    test('a v1 backup (no recurring) restores with zero recurring rules',
        () async {
      final jsonStr = json.encode({
        'schemaVersion': 1,
        'app': 'SmartSpender',
        'categories': [],
        'transactions': [],
        'budgets': [],
      });
      final result = await service.restoreFromJson(jsonStr);
      expect(result.success, isTrue);
      expect(result.recurringImported, 0);
      expect(await testDb.repositories.recurring.getAll(), isEmpty);
    });
  });

  // Keep a reference so unused-import analyzers stay quiet across model types.
  test('model types are importable', () {
    expect(Category, isNotNull);
    expect(Transaction, isNotNull);
    expect(Budget, isNotNull);
  });
}
