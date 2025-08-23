import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../database/database_helper.dart';

class BudgetProvider with ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Budget> _budgets = [];
  bool _isLoading = false;
  String? _error;

  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Budget> get activeBudgets {
    final now = DateTime.now();
    return _budgets.where((budget) {
      return budget.startDate.isBefore(now.add(const Duration(days: 1))) &&
             budget.endDate.isAfter(now.subtract(const Duration(days: 1)));
    }).toList();
  }

  Future<void> loadBudgets() async {
    _setLoading(true);
    _clearError();
    
    try {
      _budgets = await _databaseHelper.getBudgets();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load budgets: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addBudget(Budget budget) async {
    _clearError();
    
    try {
      final id = await _databaseHelper.insertBudget(budget);
      if (id > 0) {
        final newBudget = budget.copyWith(id: id);
        _budgets.add(newBudget);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to add budget: $e');
      return false;
    }
  }

  Future<bool> updateBudget(Budget budget) async {
    _clearError();
    
    try {
      final success = await _databaseHelper.updateBudget(budget);
      if (success) {
        final index = _budgets.indexWhere((b) => b.id == budget.id);
        if (index != -1) {
          _budgets[index] = budget;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update budget: $e');
      return false;
    }
  }

  Future<bool> deleteBudget(int id) async {
    _clearError();
    
    try {
      final success = await _databaseHelper.deleteBudget(id);
      if (success) {
        _budgets.removeWhere((b) => b.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to delete budget: $e');
      return false;
    }
  }

  Budget? getBudgetById(int id) {
    try {
      return _budgets.firstWhere((budget) => budget.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Budget> getBudgetsByCategory(int categoryId) {
    return _budgets.where((budget) => budget.categoryId == categoryId).toList();
  }

  Budget? getActiveBudgetForCategory(int categoryId) {
    final now = DateTime.now();
    try {
      return _budgets.firstWhere((budget) =>
          budget.categoryId == categoryId &&
          budget.startDate.isBefore(now.add(const Duration(days: 1))) &&
          budget.endDate.isAfter(now.subtract(const Duration(days: 1))));
    } catch (e) {
      return null;
    }
  }

  double calculateBudgetProgress(Budget budget, double spentAmount) {
    if (budget.amount <= 0) return 0.0;
    return (spentAmount / budget.amount).clamp(0.0, 1.0);
  }

  bool isBudgetExceeded(Budget budget, double spentAmount) {
    return spentAmount > budget.amount;
  }

  double getRemainingBudget(Budget budget, double spentAmount) {
    return (budget.amount - spentAmount).clamp(0.0, budget.amount);
  }

  List<Budget> getOverspentBudgets(Map<int, double> categorySpending) {
    return _budgets.where((budget) {
      final spent = categorySpending[budget.categoryId] ?? 0.0;
      return isBudgetExceeded(budget, spent);
    }).toList();
  }

  Map<String, double> getBudgetSummaryByPeriod() {
    final Map<String, double> summary = {
      'monthly': 0.0,
      'weekly': 0.0,
      'yearly': 0.0,
    };

    for (final budget in activeBudgets) {
      summary[budget.period] = (summary[budget.period] ?? 0.0) + budget.amount;
    }

    return summary;
  }

  double getTotalActiveBudgetAmount() {
    return activeBudgets.fold(0.0, (sum, budget) => sum + budget.amount);
  }

  List<Budget> getBudgetsNearingEnd({int daysThreshold = 7}) {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: daysThreshold));
    
    return activeBudgets.where((budget) {
      return budget.endDate.isBefore(threshold.add(const Duration(days: 1)));
    }).toList();
  }

  DateTime calculateEndDate(DateTime startDate, String period) {
    switch (period.toLowerCase()) {
      case 'weekly':
        return startDate.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(startDate.year, startDate.month + 1, startDate.day)
            .subtract(const Duration(days: 1));
      case 'yearly':
        return DateTime(startDate.year + 1, startDate.month, startDate.day)
            .subtract(const Duration(days: 1));
      default:
        return startDate.add(const Duration(days: 30)); // Default to monthly
    }
  }

  bool hasConflictingBudget(int categoryId, DateTime startDate, DateTime endDate, {int? excludeBudgetId}) {
    return _budgets.any((budget) {
      if (excludeBudgetId != null && budget.id == excludeBudgetId) {
        return false;
      }
      
      return budget.categoryId == categoryId &&
             ((startDate.isBefore(budget.endDate.add(const Duration(days: 1))) &&
               endDate.isAfter(budget.startDate.subtract(const Duration(days: 1)))));
    });
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
      _budgets.clear();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear data: $e');
    } finally {
      _setLoading(false);
    }
  }
}
