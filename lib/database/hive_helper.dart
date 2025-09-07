import 'package:hive_flutter/hive_flutter.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';

class HiveHelper {
  static const String categoriesBox = 'categories';
  static const String transactionsBox = 'transactions';
  static const String budgetsBox = 'budgets';

  static Future<void> initHive() async {
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(BudgetAdapter());
    
    // Open boxes
    await Hive.openBox<Category>(categoriesBox);
    await Hive.openBox<Transaction>(transactionsBox);
    await Hive.openBox<Budget>(budgetsBox);
  }

  // Category operations
  static Box<Category> get _categoriesBox => Hive.box<Category>(categoriesBox);

  static Future<int> insertCategory(Category category) async {
    return await _categoriesBox.add(category);
  }

  static Future<void> updateCategory(Category category) async {
    await category.save();
  }

  static Future<void> deleteCategory(int key) async {
    await _categoriesBox.delete(key);
    
    // Also delete related transactions and budgets
    await deleteTransactionsByCategory(key);
    await deleteBudgetsByCategory(key);
  }

  static List<Category> getAllCategories() {
    return _categoriesBox.values.toList();
  }

  static Category? getCategory(int key) {
    return _categoriesBox.get(key);
  }

  static List<Category> getCategoriesByType(String type) {
    return _categoriesBox.values.where((category) => category.type == type).toList();
  }

  // Transaction operations
  static Box<Transaction> get _transactionsBox => Hive.box<Transaction>(transactionsBox);

  static Future<int> insertTransaction(Transaction transaction) async {
    return await _transactionsBox.add(transaction);
  }

  static Future<void> updateTransaction(Transaction transaction) async {
    await transaction.save();
  }

  static Future<void> deleteTransaction(int key) async {
    await _transactionsBox.delete(key);
  }

  static Future<void> deleteTransactionsByCategory(int categoryKey) async {
    final transactions = _transactionsBox.values
        .where((transaction) => transaction.categoryKey == categoryKey)
        .toList();
    
    for (final transaction in transactions) {
      await transaction.delete();
    }
  }

  static List<Transaction> getAllTransactions() {
    return _transactionsBox.values.toList();
  }

  static Transaction? getTransaction(int key) {
    return _transactionsBox.get(key);
  }

  static List<Transaction> getTransactionsByCategory(int categoryKey) {
    return _transactionsBox.values
        .where((transaction) => transaction.categoryKey == categoryKey)
        .toList();
  }

  static List<Transaction> getTransactionsByType(String type) {
    return _transactionsBox.values
        .where((transaction) => transaction.type == type)
        .toList();
  }

  static List<Transaction> getTransactionsByDateRange(DateTime startDate, DateTime endDate) {
    return _transactionsBox.values
        .where((transaction) => 
            transaction.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList();
  }

  static List<Transaction> getTransactionsWithCategoryInfo() {
    final transactions = getAllTransactions();
    final categories = getAllCategories();
    
    // Create a map for quick category lookup
    final categoryMap = <int, Category>{};
    for (final category in categories) {
      if (category.key != null) {
        categoryMap[category.key!] = category;
      }
    }
    
    // Add category info to transactions
    for (final transaction in transactions) {
      final category = categoryMap[transaction.categoryKey];
      if (category != null) {
        transaction.categoryName = category.name;
        transaction.categoryIcon = category.icon;
        transaction.categoryColor = category.color;
      }
    }
    
    return transactions;
  }

  // Budget operations
  static Box<Budget> get _budgetsBox => Hive.box<Budget>(budgetsBox);

  static Future<int> insertBudget(Budget budget) async {
    return await _budgetsBox.add(budget);
  }

  static Future<void> updateBudget(Budget budget) async {
    await budget.save();
  }

  static Future<void> deleteBudget(int key) async {
    await _budgetsBox.delete(key);
  }

  static Future<void> deleteBudgetsByCategory(int categoryKey) async {
    final budgets = _budgetsBox.values
        .where((budget) => budget.categoryKey == categoryKey)
        .toList();
    
    for (final budget in budgets) {
      await budget.delete();
    }
  }

  static List<Budget> getAllBudgets() {
    return _budgetsBox.values.toList();
  }

  static Budget? getBudget(int key) {
    return _budgetsBox.get(key);
  }

  static List<Budget> getBudgetsByCategory(int categoryKey) {
    return _budgetsBox.values
        .where((budget) => budget.categoryKey == categoryKey)
        .toList();
  }

  static List<Budget> getActiveBudgets() {
    return _budgetsBox.values
        .where((budget) => budget.isActive)
        .toList();
  }

  static List<Budget> getBudgetsWithCategoryInfo() {
    final budgets = getAllBudgets();
    final categories = getAllCategories();
    
    // Create a map for quick category lookup
    final categoryMap = <int, Category>{};
    for (final category in categories) {
      if (category.key != null) {
        categoryMap[category.key!] = category;
      }
    }
    
    // Add category info to budgets
    for (final budget in budgets) {
      final category = categoryMap[budget.categoryKey];
      if (category != null) {
        budget.categoryName = category.name;
        budget.categoryIcon = category.icon;
        budget.categoryColor = category.color;
      }
    }
    
    return budgets;
  }

  // Analytics methods
  static double getTotalIncome({DateTime? startDate, DateTime? endDate}) {
    var transactions = getTransactionsByType('income');
    
    if (startDate != null && endDate != null) {
      transactions = transactions
          .where((t) => 
              t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();
    }
    
    return transactions.fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  static double getTotalExpenses({DateTime? startDate, DateTime? endDate}) {
    var transactions = getTransactionsByType('expense');
    
    if (startDate != null && endDate != null) {
      transactions = transactions
          .where((t) => 
              t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();
    }
    
    return transactions.fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  static Map<String, double> getExpensesByCategory({DateTime? startDate, DateTime? endDate}) {
    var transactions = getTransactionsByType('expense');
    
    if (startDate != null && endDate != null) {
      transactions = transactions
          .where((t) => 
              t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();
    }
    
    final categories = getAllCategories();
    final categoryMap = <int, String>{};
    for (final category in categories) {
      if (category.key != null) {
        categoryMap[category.key!] = category.name;
      }
    }
    
    final expensesByCategory = <String, double>{};
    for (final transaction in transactions) {
      final categoryName = categoryMap[transaction.categoryKey] ?? 'Unknown';
      expensesByCategory[categoryName] = 
          (expensesByCategory[categoryName] ?? 0.0) + transaction.amount;
    }
    
    return expensesByCategory;
  }

  // Utility methods
  static Future<void> clearAllData() async {
    await _categoriesBox.clear();
    await _transactionsBox.clear();
    await _budgetsBox.clear();
  }

  static Future<void> closeBoxes() async {
    await _categoriesBox.close();
    await _transactionsBox.close();
    await _budgetsBox.close();
  }
}
