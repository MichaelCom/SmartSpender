import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../database/hive_helper.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Transaction> get incomeTransactions => 
      _transactions.where((t) => t.type == 'income').toList();
  
  List<Transaction> get expenseTransactions => 
      _transactions.where((t) => t.type == 'expense').toList();

  double get totalIncome => incomeTransactions
      .fold(0.0, (sum, transaction) => sum + transaction.amount);

  double get totalExpenses => expenseTransactions
      .fold(0.0, (sum, transaction) => sum + transaction.amount);

  double get balance => totalIncome - totalExpenses;

  Future<void> loadTransactions() async {
    _setLoading(true);
    _clearError();
    
    try {
      _transactions = HiveHelper.getTransactionsWithCategoryInfo();
      // Sort by date (newest first)
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    } catch (e) {
      _setError('Failed to load transactions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addTransaction(Transaction transaction) async {
    _clearError();
    
    try {
      await HiveHelper.insertTransaction(transaction);
      // Reload transactions to get the updated list with keys and category info
      await loadTransactions();
      return true;
    } catch (e) {
      _setError('Failed to add transaction: $e');
      return false;
    }
  }

  Future<bool> updateTransaction(Transaction transaction) async {
    _clearError();
    
    try {
      await HiveHelper.updateTransaction(transaction);
      await loadTransactions();
      return true;
    } catch (e) {
      _setError('Failed to update transaction: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(int key) async {
    _clearError();
    
    try {
      await HiveHelper.deleteTransaction(key);
      await loadTransactions();
      return true;
    } catch (e) {
      _setError('Failed to delete transaction: $e');
      return false;
    }
  }

  List<Transaction> getTransactionsByCategory(int categoryKey) {
    return HiveHelper.getTransactionsByCategory(categoryKey);
  }

  List<Transaction> getTransactionsByDateRange(DateTime startDate, DateTime endDate) {
    return HiveHelper.getTransactionsByDateRange(startDate, endDate);
  }

  List<Transaction> getRecentTransactions({int limit = 10}) {
    final sortedTransactions = List<Transaction>.from(_transactions);
    sortedTransactions.sort((a, b) => b.date.compareTo(a.date));
    return sortedTransactions.take(limit).toList();
  }

  double getTotalAmountByCategory(int categoryKey) {
    return _transactions
        .where((t) => t.categoryKey == categoryKey)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getMonthlyIncome(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    return _transactions
        .where((t) => 
            t.type == 'income' &&
            t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getMonthlyExpenses(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    return _transactions
        .where((t) => 
            t.type == 'expense' &&
            t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  Map<int, double> getCategoryExpenseSummary() {
    final Map<int, double> summary = {};
    
    for (final transaction in expenseTransactions) {
      summary[transaction.categoryKey] = 
          (summary[transaction.categoryKey] ?? 0.0) + transaction.amount;
    }
    
    return summary;
  }

  List<Transaction> searchTransactions(String query) {
    if (query.isEmpty) return _transactions;
    
    final lowercaseQuery = query.toLowerCase();
    return _transactions.where((transaction) {
      return transaction.description?.toLowerCase().contains(lowercaseQuery) ?? false;
    }).toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Clear all data and reload
  Future<void> clearAllData() async {
    _setLoading(true);
    _clearError();
    
    try {
      _transactions.clear();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear data: $e');
    } finally {
      _setLoading(false);
    }
  }
}
