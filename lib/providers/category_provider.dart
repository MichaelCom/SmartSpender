import 'package:flutter/foundation.dart';
import '../models/category.dart' as models;
import '../database/hive_helper.dart';

class CategoryProvider with ChangeNotifier {
  List<models.Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<models.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<models.Category> get incomeCategories =>
      _categories.where((cat) => cat.type == 'income').toList();

  List<models.Category> get expenseCategories =>
      _categories.where((cat) => cat.type == 'expense').toList();

  Future<void> loadCategories() async {
    _setLoading(true);
    _clearError();

    try {
      _categories = HiveHelper.getAllCategories();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load categories: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addCategory(models.Category category) async {
    _clearError();

    try {
      await HiveHelper.insertCategory(category);
      // Reload categories to get the updated list with keys
      await loadCategories();
      return true;
    } catch (e) {
      _setError('Failed to add category: $e');
      return false;
    }
  }

  Future<bool> updateCategory(models.Category category) async {
    _clearError();

    try {
      await HiveHelper.updateCategory(category);
      await loadCategories();
      return true;
    } catch (e) {
      _setError('Failed to update category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(int key) async {
    _clearError();

    try {
      await HiveHelper.deleteCategory(key);
      await loadCategories();
      return true;
    } catch (e) {
      _setError('Failed to delete category: $e');
      return false;
    }
  }

  models.Category? getCategoryByKey(int key) {
    return HiveHelper.getCategory(key);
  }

  // Backward compatibility method - maps key to id
  models.Category? getCategoryById(int id) {
    return getCategoryByKey(id);
  }

  Future<void> initializeDefaultCategories() async {
    if (_categories.isNotEmpty) return;

    final defaultCategories = [
      // Income categories
      models.Category(
        name: 'Salary',
        type: 'income',
        color: '#4CAF50',
        icon: 'work',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Investment',
        type: 'income',
        color: '#FF9800',
        icon: 'trending_up',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Other Income',
        type: 'income',
        color: '#9C27B0',
        icon: 'attach_money',
        createdAt: DateTime.now(),
      ),

      // Expense categories
      models.Category(
        name: 'Food & Dining',
        type: 'expense',
        color: '#F44336',
        icon: 'restaurant',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Transportation',
        type: 'expense',
        color: '#3F51B5',
        icon: 'directions_car',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Shopping',
        type: 'expense',
        color: '#E91E63',
        icon: 'shopping_bag',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Entertainment',
        type: 'expense',
        color: '#9C27B0',
        icon: 'movie',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Bills & Utilities',
        type: 'expense',
        color: '#607D8B',
        icon: 'receipt',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Healthcare',
        type: 'expense',
        color: '#4CAF50',
        icon: 'local_hospital',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Education',
        type: 'expense',
        color: '#FF9800',
        icon: 'school',
        createdAt: DateTime.now(),
      ),
      models.Category(
        name: 'Other Expenses',
        type: 'expense',
        color: '#795548',
        icon: 'category',
        createdAt: DateTime.now(),
      ),
    ];

    try {
      for (final category in defaultCategories) {
        await HiveHelper.insertCategory(category);
      }
      await loadCategories();
    } catch (e) {
      _setError('Failed to initialize default categories: $e');
    }
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
      await HiveHelper.clearAllData();
      _categories.clear();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear data: $e');
    } finally {
      _setLoading(false);
    }
  }
}
