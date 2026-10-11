import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import 'repositories.dart';

/// Drift-backed implementation of [AppRepositories].
class DriftRepositories implements AppRepositories {
  DriftRepositories(this._db)
      : categories = _DriftCategoryRepository(_db),
        transactions = _DriftTransactionRepository(_db),
        budgets = _DriftBudgetRepository(_db),
        recurring = _DriftRecurringTransactionRepository(_db);

  final AppDatabase _db;

  @override
  final CategoryRepository categories;
  @override
  final TransactionRepository transactions;
  @override
  final BudgetRepository budgets;
  @override
  final RecurringTransactionRepository recurring;

  @override
  Future<void> clearAllData() async {
    await _db.transaction(() async {
      // Order matters only without cascade; with FKs on, deleting categories
      // would cascade budgets and null-out transactions, so clear children
      // first to be explicit and avoid surprises.
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.recurringTransactions).go();
      await _db.delete(_db.categories).go();
    });
  }
}

// ---------------------------------------------------------------------------
// Mapping helpers
// ---------------------------------------------------------------------------

Category _toCategory(CategoryRow r) => Category(
      id: r.id,
      name: r.name,
      type: r.type,
      color: r.color,
      icon: r.icon,
      createdAt: r.createdAt,
    );

Transaction _toTransaction(TransactionRow r, {CategoryRow? category}) =>
    Transaction(
      id: r.id,
      amount: r.amount,
      description: r.description,
      categoryId: r.categoryId,
      date: r.date,
      type: r.type,
      createdAt: r.createdAt,
      recurringId: r.recurringId,
      categoryName: category?.name,
      categoryIcon: category?.icon,
      categoryColor: category?.color,
    );

Budget _toBudget(BudgetRow r, {CategoryRow? category}) => Budget(
      id: r.id,
      categoryId: r.categoryId,
      amount: r.amount,
      period: r.period,
      startDate: r.startDate,
      endDate: r.endDate,
      createdAt: r.createdAt,
      description: r.description,
      categoryName: category?.name,
      categoryIcon: category?.icon,
      categoryColor: category?.color,
    );

RecurringTransaction _toRecurring(RecurringTransactionRow r,
        {CategoryRow? category}) =>
    RecurringTransaction(
      id: r.id,
      amount: r.amount,
      description: r.description,
      categoryId: r.categoryId,
      type: r.type,
      frequency: r.frequency,
      startDate: r.startDate,
      endDate: r.endDate,
      lastGeneratedDate: r.lastGeneratedDate,
      createdAt: r.createdAt,
      categoryName: category?.name,
      categoryIcon: category?.icon,
      categoryColor: category?.color,
    );
// ---------------------------------------------------------------------------
// Category repository
// ---------------------------------------------------------------------------

class _DriftCategoryRepository implements CategoryRepository {
  _DriftCategoryRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<Category>> getAll() async {
    final rows = await _db.select(_db.categories).get();
    return rows.map(_toCategory).toList();
  }

  @override
  Future<Category?> getById(int id) async {
    final row = await (_db.select(_db.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toCategory(row);
  }

  @override
  Future<List<Category>> getByType(String type) async {
    final rows = await (_db.select(_db.categories)
          ..where((c) => c.type.equals(type)))
        .get();
    return rows.map(_toCategory).toList();
  }

  @override
  Future<int> insert(Category category) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: category.name,
            type: category.type,
            color: Value(category.color),
            icon: Value(category.icon),
            createdAt: category.createdAt,
          ),
        );
  }

  @override
  Future<void> update(Category category) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(category.id!)))
        .write(
      CategoriesCompanion(
        name: Value(category.name),
        type: Value(category.type),
        color: Value(category.color),
        icon: Value(category.icon),
        createdAt: Value(category.createdAt),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}

// ---------------------------------------------------------------------------
// Transaction repository
// ---------------------------------------------------------------------------

class _DriftTransactionRepository implements TransactionRepository {
  _DriftTransactionRepository(this._db);
  final AppDatabase _db;

  /// Runs a left-outer join so uncategorised transactions are still returned.
  Future<List<Transaction>> _selectJoined(
      Expression<bool> Function(
              $TransactionsTable t, $CategoriesTable c)?
          filter) async {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);
    if (filter != null) {
      query.where(filter(_db.transactions, _db.categories));
    }
    final rows = await query.get();
    return rows.map((row) {
      final tx = row.readTable(_db.transactions);
      final cat = row.readTableOrNull(_db.categories);
      return _toTransaction(tx, category: cat);
    }).toList();
  }

  @override
  Future<List<Transaction>> getAllWithCategoryInfo() => _selectJoined(null);

  @override
  Future<Transaction?> getById(int id) async {
    final result =
        await _selectJoined((t, c) => t.id.equals(id));
    return result.isEmpty ? null : result.first;
  }

  @override
  Future<List<Transaction>> getByCategory(int categoryId) =>
      _selectJoined((t, c) => t.categoryId.equals(categoryId));

  @override
  Future<List<Transaction>> getByType(String type) =>
      _selectJoined((t, c) => t.type.equals(type));

  @override
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) {
    return _selectJoined(
      (t, c) => t.date.isBetweenValues(
        _startOfDay(start),
        _endOfDay(end),
      ),
    );
  }

  @override
  Future<int> insert(Transaction transaction) {
    return _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: transaction.amount,
            description: Value(transaction.description),
            categoryId: Value(transaction.categoryId),
            date: transaction.date,
            type: transaction.type,
            createdAt: transaction.createdAt,
            recurringId: Value(transaction.recurringId),
          ),
        );
  }

  @override
  Future<void> update(Transaction transaction) async {
    await (_db.update(_db.transactions)
          ..where((t) => t.id.equals(transaction.id!)))
        .write(
      TransactionsCompanion(
        amount: Value(transaction.amount),
        description: Value(transaction.description),
        categoryId: Value(transaction.categoryId),
        date: Value(transaction.date),
        type: Value(transaction.type),
        createdAt: Value(transaction.createdAt),
        recurringId: Value(transaction.recurringId),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<double> getTotalIncome({DateTime? startDate, DateTime? endDate}) {
    return _sumByType('income', startDate: startDate, endDate: endDate);
  }

  @override
  Future<double> getTotalExpenses({DateTime? startDate, DateTime? endDate}) {
    return _sumByType('expense', startDate: startDate, endDate: endDate);
  }

  Future<double> _sumByType(
    String type, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final amount = _db.transactions.amount;
    final sum = amount.sum();
    final query = _db.selectOnly(_db.transactions)..addColumns([sum]);
    query.where(_db.transactions.type.equals(type));
    if (startDate != null && endDate != null) {
      query.where(_db.transactions.date
          .isBetweenValues(_startOfDay(startDate), _endOfDay(endDate)));
    }
    final row = await query.getSingle();
    return row.read(sum) ?? 0.0;
  }

  @override
  Future<Map<String, double>> getExpensesByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);
    query
      ..addColumns([_db.categories.name, amountSum])
      ..where(_db.transactions.type.equals('expense'))
      ..groupBy([_db.transactions.categoryId]);
    if (startDate != null && endDate != null) {
      query.where(_db.transactions.date
          .isBetweenValues(_startOfDay(startDate), _endOfDay(endDate)));
    }

    final rows = await query.get();
    final result = <String, double>{};
    for (final row in rows) {
      final name = row.read(_db.categories.name) ?? 'Uncategorised';
      result[name] = row.read(amountSum) ?? 0.0;
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Budget repository
// ---------------------------------------------------------------------------

class _DriftBudgetRepository implements BudgetRepository {
  _DriftBudgetRepository(this._db);
  final AppDatabase _db;

  Future<List<Budget>> _selectJoined(
      Expression<bool> Function($BudgetsTable b)? filter) async {
    final query = _db.select(_db.budgets).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.budgets.categoryId),
      ),
    ]);
    if (filter != null) {
      query.where(filter(_db.budgets));
    }
    final rows = await query.get();
    return rows.map((row) {
      final b = row.readTable(_db.budgets);
      final cat = row.readTableOrNull(_db.categories);
      return _toBudget(b, category: cat);
    }).toList();
  }

  @override
  Future<List<Budget>> getAllWithCategoryInfo() => _selectJoined(null);

  @override
  Future<Budget?> getById(int id) async {
    final result = await _selectJoined((b) => b.id.equals(id));
    return result.isEmpty ? null : result.first;
  }

  @override
  Future<List<Budget>> getByCategory(int categoryId) =>
      _selectJoined((b) => b.categoryId.equals(categoryId));

  @override
  Future<int> insert(Budget budget) {
    return _db.into(_db.budgets).insert(
          BudgetsCompanion.insert(
            categoryId: budget.categoryId,
            amount: budget.amount,
            period: budget.period,
            startDate: budget.startDate,
            endDate: budget.endDate,
            createdAt: budget.createdAt,
            description: Value(budget.description),
          ),
        );
  }

  @override
  Future<void> update(Budget budget) async {
    await (_db.update(_db.budgets)..where((b) => b.id.equals(budget.id!)))
        .write(
      BudgetsCompanion(
        categoryId: Value(budget.categoryId),
        amount: Value(budget.amount),
        period: Value(budget.period),
        startDate: Value(budget.startDate),
        endDate: Value(budget.endDate),
        createdAt: Value(budget.createdAt),
        description: Value(budget.description),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
  }
}

// ---------------------------------------------------------------------------
// Recurring transaction repository
// ---------------------------------------------------------------------------

class _DriftRecurringTransactionRepository
    implements RecurringTransactionRepository {
  _DriftRecurringTransactionRepository(this._db);
  final AppDatabase _db;

  Future<List<RecurringTransaction>> _selectJoined(
      Expression<bool> Function($RecurringTransactionsTable r)?
          filter) async {
    final query = _db.select(_db.recurringTransactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.recurringTransactions.categoryId),
      ),
    ]);
    if (filter != null) {
      query.where(filter(_db.recurringTransactions));
    }
    final rows = await query.get();
    return rows.map((row) {
      final r = row.readTable(_db.recurringTransactions);
      final cat = row.readTableOrNull(_db.categories);
      return _toRecurring(r, category: cat);
    }).toList();
  }

  @override
  Future<List<RecurringTransaction>> getAll() => _selectJoined(null);

  @override
  Future<RecurringTransaction?> getById(int id) async {
    final result = await _selectJoined((r) => r.id.equals(id));
    return result.isEmpty ? null : result.first;
  }

  @override
  Future<int> insert(RecurringTransaction recurring) {
    return _db.into(_db.recurringTransactions).insert(
          RecurringTransactionsCompanion.insert(
            amount: recurring.amount,
            description: Value(recurring.description),
            categoryId: Value(recurring.categoryId),
            type: recurring.type,
            frequency: recurring.frequency,
            startDate: recurring.startDate,
            endDate: Value(recurring.endDate),
            lastGeneratedDate: Value(recurring.lastGeneratedDate),
            createdAt: recurring.createdAt,
          ),
        );
  }

  @override
  Future<void> update(RecurringTransaction recurring) async {
    await (_db.update(_db.recurringTransactions)
          ..where((r) => r.id.equals(recurring.id!)))
        .write(
      RecurringTransactionsCompanion(
        amount: Value(recurring.amount),
        description: Value(recurring.description),
        categoryId: Value(recurring.categoryId),
        type: Value(recurring.type),
        frequency: Value(recurring.frequency),
        startDate: Value(recurring.startDate),
        endDate: Value(recurring.endDate),
        lastGeneratedDate: Value(recurring.lastGeneratedDate),
        createdAt: Value(recurring.createdAt),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.recurringTransactions)..where((r) => r.id.equals(id)))
        .go();
  }
}

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
