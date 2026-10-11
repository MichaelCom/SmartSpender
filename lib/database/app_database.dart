import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Category table. The `type` column is either 'income' or 'expense'.
@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Transaction table. `categoryId` is nullable: when a category is deleted the
/// transaction is kept and its category is set to null (uncategorised).
/// `recurringId` links a transaction back to the recurring rule that generated
/// it; when that rule is deleted the transaction is kept (set null).
@TableIndex(name: 'idx_transactions_category', columns: {#categoryId})
@TableIndex(name: 'idx_transactions_date', columns: {#date})
@DataClassName('TransactionRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get recurringId => integer()
      .nullable()
      .references(RecurringTransactions, #id, onDelete: KeyAction.setNull)();
}

/// Recurring transaction rule. Generates concrete [Transactions] on a schedule.
/// `categoryId` is nullable (SET NULL on category delete). `type` is
/// income|expense; `frequency` is daily|weekly|monthly|yearly.
@DataClassName('RecurringTransactionRow')
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  IntColumn get categoryId => integer()
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get type => text()();
  TextColumn get frequency => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get lastGeneratedDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Budget table. A budget always belongs to a category, so deleting a category
/// cascades to (deletes) its budgets.
@TableIndex(name: 'idx_budgets_category', columns: {#categoryId})
@DataClassName('BudgetRow')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  TextColumn get period => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get description => text().nullable()();
}

@DriftDatabase(
    tables: [Categories, Transactions, Budgets, RecurringTransactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Testing constructor that accepts an in-memory (or custom) executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 -> v2: add recurring transactions table + recurringId column.
            await m.createTable(recurringTransactions);
            await m.addColumn(transactions, transactions.recurringId);
          }
        },
        beforeOpen: (details) async {
          // Required for ON DELETE CASCADE / SET NULL to be honoured by SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'smart_spender');
}
