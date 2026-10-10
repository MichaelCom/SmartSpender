import 'package:drift/native.dart';
import 'package:smart_spender/database/app_database.dart';
import 'package:smart_spender/models/budget.dart';
import 'package:smart_spender/models/category.dart';
import 'package:smart_spender/models/transaction.dart';
import 'package:smart_spender/repositories/drift_repositories.dart';
import 'package:smart_spender/repositories/repositories.dart';

/// Spins up an in-memory Drift database and matching repositories for tests.
class TestDb {
  TestDb._(this.database, this.repositories);

  final AppDatabase database;
  final AppRepositories repositories;

  static TestDb create() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    return TestDb._(db, DriftRepositories(db));
  }

  Future<void> dispose() => database.close();
}

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

Transaction makeTransaction({
  double amount = 100.0,
  String? description = 'Test tx',
  int? categoryId,
  DateTime? date,
  String type = 'expense',
  DateTime? createdAt,
}) {
  return Transaction(
    amount: amount,
    description: description,
    categoryId: categoryId,
    date: date ?? DateTime(2024, 6, 15),
    type: type,
    createdAt: createdAt ?? DateTime(2024, 6, 15),
  );
}

Budget makeBudget({
  int categoryId = 0,
  double amount = 1000.0,
  String period = 'monthly',
  DateTime? startDate,
  DateTime? endDate,
  DateTime? createdAt,
  String? description,
}) {
  final start = startDate ?? DateTime(2024, 6, 1);
  return Budget(
    categoryId: categoryId,
    amount: amount,
    period: period,
    startDate: start,
    endDate: endDate ?? DateTime(2024, 6, 30),
    createdAt: createdAt ?? start,
    description: description,
  );
}
