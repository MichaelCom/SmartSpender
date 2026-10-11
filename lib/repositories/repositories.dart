import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';

/// Abstractions over persistence. Providers depend on these interfaces, not on
/// any concrete database, which keeps the storage backend swappable and makes
/// the providers testable with fakes.
abstract class CategoryRepository {
  Future<List<Category>> getAll();
  Future<Category?> getById(int id);
  Future<List<Category>> getByType(String type);
  Future<int> insert(Category category);
  Future<void> update(Category category);
  Future<void> delete(int id);
}

abstract class TransactionRepository {
  Future<List<Transaction>> getAllWithCategoryInfo();
  Future<Transaction?> getById(int id);
  Future<List<Transaction>> getByCategory(int categoryId);
  Future<List<Transaction>> getByType(String type);
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);
  Future<int> insert(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(int id);

  Future<double> getTotalIncome({DateTime? startDate, DateTime? endDate});
  Future<double> getTotalExpenses({DateTime? startDate, DateTime? endDate});
  Future<Map<String, double>> getExpensesByCategory({
    DateTime? startDate,
    DateTime? endDate,
  });
}

abstract class BudgetRepository {
  Future<List<Budget>> getAllWithCategoryInfo();
  Future<Budget?> getById(int id);
  Future<List<Budget>> getByCategory(int categoryId);
  Future<int> insert(Budget budget);
  Future<void> update(Budget budget);
  Future<void> delete(int id);
}

abstract class RecurringTransactionRepository {
  Future<List<RecurringTransaction>> getAll();
  Future<RecurringTransaction?> getById(int id);
  Future<int> insert(RecurringTransaction recurring);
  Future<void> update(RecurringTransaction recurring);
  Future<void> delete(int id);
}

/// Groups the repositories together for easy injection and a single
/// "clear everything" entry point.
abstract class AppRepositories {
  CategoryRepository get categories;
  TransactionRepository get transactions;
  BudgetRepository get budgets;
  RecurringTransactionRepository get recurring;

  Future<void> clearAllData();
}
