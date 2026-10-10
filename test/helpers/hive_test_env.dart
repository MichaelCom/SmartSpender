import 'dart:io';

import 'package:hive/hive.dart';
import 'package:smart_spender/database/hive_helper.dart';
import 'package:smart_spender/models/budget.dart';
import 'package:smart_spender/models/category.dart';
import 'package:smart_spender/models/transaction.dart';

/// Spins up a real Hive instance backed by a temporary directory so the static
/// [HiveHelper] methods (which use `Hive.box<T>(name)`) work in unit tests
/// without needing Flutter plugin bindings or `Hive.initFlutter()`.
class HiveTestEnv {
  HiveTestEnv._(this.directory);

  final Directory directory;

  static bool _adaptersRegistered = false;

  /// Initializes Hive against a fresh temp dir and opens the app's boxes.
  static Future<HiveTestEnv> setUp() async {
    final dir = await Directory.systemTemp.createTemp('smartspender_hive_test');
    Hive.init(dir.path);

    // Adapters are process-global; only register once across all tests.
    if (!_adaptersRegistered) {
      Hive.registerAdapter(CategoryAdapter());
      Hive.registerAdapter(TransactionAdapter());
      Hive.registerAdapter(BudgetAdapter());
      _adaptersRegistered = true;
    }

    await Hive.openBox<Category>(HiveHelper.categoriesBox);
    await Hive.openBox<Transaction>(HiveHelper.transactionsBox);
    await Hive.openBox<Budget>(HiveHelper.budgetsBox);

    return HiveTestEnv._(dir);
  }

  /// Closes every box and deletes the temp directory.
  Future<void> tearDown() async {
    await Hive.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

/// Convenience factory for a [Category] with sensible test defaults.
Category makeCategory({
  String name = 'Test',
  String type = 'expense',
  String? color = '#000000',
  String? icon = 'category',
  DateTime? createdAt,
}) {
  return Category(
    name: name,
    type: type,
    color: color,
    icon: icon,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
  );
}

/// Convenience factory for a [Transaction] with sensible test defaults.
Transaction makeTransaction({
  double amount = 100.0,
  String? description = 'Test tx',
  int categoryKey = 0,
  DateTime? date,
  String type = 'expense',
  DateTime? createdAt,
}) {
  return Transaction(
    amount: amount,
    description: description,
    categoryKey: categoryKey,
    date: date ?? DateTime(2024, 6, 15),
    type: type,
    createdAt: createdAt ?? DateTime(2024, 6, 15),
  );
}

/// Convenience factory for a [Budget] with sensible test defaults.
Budget makeBudget({
  int categoryKey = 0,
  double amount = 1000.0,
  String period = 'monthly',
  DateTime? startDate,
  DateTime? endDate,
  DateTime? createdAt,
  String? description,
}) {
  final start = startDate ?? DateTime(2024, 6, 1);
  return Budget(
    categoryKey: categoryKey,
    amount: amount,
    period: period,
    startDate: start,
    endDate: endDate ?? DateTime(2024, 6, 30),
    createdAt: createdAt ?? start,
    description: description,
  );
}
