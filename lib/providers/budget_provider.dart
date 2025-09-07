import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../database/hive_helper.dart';

class BudgetProvider with ChangeNotifier {
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
      _budgets = HiveHelper.getBudgetsWithCategoryInfo();
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
      await HiveHelper.insertBudget(budget);
      // Reload budgets to get the updated list with keys and category info
      await loadBudgets();
      return true;
    } catch (e) {
      _setError('Failed to add budget: $e');
      return false;
    }
  }

  Future<bool> updateBudget(Budget budget) async {
    _clearError();
    
    try {
      await HiveHelper.updateBudget(budget);
      await loadBudgets();
      return true;
    } catch (e) {
      _setError('Failed to update budget: $e');
      return false;
    }
  }

  Future<bool> deleteBudget(int key) async {
    _clearError();
    
    try {
      await HiveHelper.deleteBudget(key);
      await loadBudgets();
      return true;
    } catch (e) {
      _setError('Failed to delete budget: $e');
      return false;
    }
  }

  Budget? getBudgetByKey(int key) {
    return HiveHelper.getBudget(key);
  }

  List<Budget> getBudgetsByCategory(int categoryKey) {
    return HiveHelper.getBudgetsByCategory(categoryKey);
  }

  Budget? getActiveBudgetForCategory(int categoryKey) {
    final now = DateTime.now();
    try {
      return _budgets.firstWhere((budget) =>
          budget.categoryKey == categoryKey &&
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
      final spent = categorySpending[budget.categoryKey] ?? 0.0;
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

  bool hasConflictingBudget(int categoryKey, DateTime startDate, DateTime endDate, {int? excludeBudgetKey}) {
    return _budgets.any((budget) {
      if (excludeBudgetKey != null && budget.key == excludeBudgetKey) {
        return false;
      }
      
      return budget.categoryKey == categoryKey &&
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
