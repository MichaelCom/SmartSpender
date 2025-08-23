import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../database/database_helper.dart';

class TransactionProvider with ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
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
      _transactions = await _databaseHelper.getTransactions();
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
      final id = await _databaseHelper.insertTransaction(transaction);
      if (id > 0) {
        final newTransaction = transaction.copyWith(id: id);
        _transactions.add(newTransaction);
        // Re-sort after adding
        _transactions.sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to add transaction: $e');
      return false;
    }
  }

  Future<bool> updateTransaction(Transaction transaction) async {
    _clearError();
    
    try {
      final success = await _databaseHelper.updateTransaction(transaction);
      if (success) {
        final index = _transactions.indexWhere((t) => t.id == transaction.id);
        if (index != -1) {
          _transactions[index] = transaction;
          // Re-sort after updating
          _transactions.sort((a, b) => b.date.compareTo(a.date));
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update transaction: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    _clearError();
    
    try {
      final success = await _databaseHelper.deleteTransaction(id);
      if (success) {
        _transactions.removeWhere((t) => t.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to delete transaction: $e');
      return false;
    }
  }

  List<Transaction> getTransactionsByCategory(int categoryId) {
    return _transactions.where((t) => t.categoryId == categoryId).toList();
  }

  List<Transaction> getTransactionsByDateRange(DateTime startDate, DateTime endDate) {
    return _transactions.where((t) {
      return t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             t.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  List<Transaction> getRecentTransactions({int limit = 10}) {
    final sortedTransactions = List<Transaction>.from(_transactions);
    sortedTransactions.sort((a, b) => b.date.compareTo(a.date));
    return sortedTransactions.take(limit).toList();
  }

  double getTotalAmountByCategory(int categoryId) {
    return _transactions
        .where((t) => t.categoryId == categoryId)
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
      summary[transaction.categoryId] = 
          (summary[transaction.categoryId] ?? 0.0) + transaction.amount;
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
