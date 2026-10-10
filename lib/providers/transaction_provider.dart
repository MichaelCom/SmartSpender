import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../repositories/repositories.dart';

class TransactionProvider with ChangeNotifier {
  TransactionProvider(this._repository);

  final TransactionRepository _repository;

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

  double get totalIncome =>
      incomeTransactions.fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenses =>
      expenseTransactions.fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpenses;

  Future<void> loadTransactions() async {
    _setLoading(true);
    _clearError();

    try {
      _transactions = await _repository.getAllWithCategoryInfo();
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
      await _repository.insert(transaction);
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
      await _repository.update(transaction);
      await loadTransactions();
      return true;
    } catch (e) {
      _setError('Failed to update transaction: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    _clearError();

    try {
      await _repository.delete(id);
      await loadTransactions();
      return true;
    } catch (e) {
      _setError('Failed to delete transaction: $e');
      return false;
    }
  }

  List<Transaction> getTransactionsByCategory(int categoryId) {
    return _transactions.where((t) => t.categoryId == categoryId).toList();
  }

  List<Transaction> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) {
    return _transactions
        .where((t) =>
            t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList();
  }

  List<Transaction> getRecentTransactions({int limit = 10}) {
    final sorted = List<Transaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }

  double getTotalAmountByCategory(int categoryId) {
    return _transactions
        .where((t) => t.categoryId == categoryId)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getMonthlyIncome(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    return _transactions
        .where((t) =>
            t.type == 'income' &&
            t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getMonthlyExpenses(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    return _transactions
        .where((t) =>
            t.type == 'expense' &&
            t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<int, double> getCategoryExpenseSummary() {
    final Map<int, double> summary = {};

    for (final transaction in expenseTransactions) {
      final categoryId = transaction.categoryId;
      if (categoryId == null) continue;
      summary[categoryId] = (summary[categoryId] ?? 0.0) + transaction.amount;
    }

    return summary;
  }

  List<Transaction> searchTransactions(String query) {
    if (query.isEmpty) return _transactions;

    final lowercaseQuery = query.toLowerCase();
    return _transactions.where((transaction) {
      return transaction.description?.toLowerCase().contains(lowercaseQuery) ??
          false;
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

  /// Resets in-memory state. Persistence is cleared via [AppRepositories].
  Future<void> clearAllData() async {
    _transactions = [];
    notifyListeners();
  }
}
