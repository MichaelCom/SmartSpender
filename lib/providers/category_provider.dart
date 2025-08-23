import 'package:flutter/foundation.dart';
import '../models/category.dart' as model;
import '../database/database_helper.dart';

class CategoryProvider with ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<model.Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<model.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<model.Category> get incomeCategories =>
      _categories.where((cat) => cat.type == 'income').toList();

  List<model.Category> get expenseCategories =>
      _categories.where((cat) => cat.type == 'expense').toList();

  Future<void> loadCategories() async {
    _setLoading(true);
    _clearError();

    try {
      _categories = await _databaseHelper.getCategories();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load categories: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addCategory(model.Category category) async {
    _clearError();

    try {
      final id = await _databaseHelper.insertCategory(category);
      if (id > 0) {
        final newCategory = category.copyWith(id: id);
        _categories.add(newCategory);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to add category: $e');
      return false;
    }
  }

  Future<bool> updateCategory(model.Category category) async {
    _clearError();

    try {
      final success = await _databaseHelper.updateCategory(category);
      if (success) {
        final index = _categories.indexWhere((cat) => cat.id == category.id);
        if (index != -1) {
          _categories[index] = category;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to update category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    _clearError();

    try {
      final success = await _databaseHelper.deleteCategory(id);
      if (success) {
        _categories.removeWhere((cat) => cat.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Failed to delete category: $e');
      return false;
    }
  }

  model.Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> initializeDefaultCategories() async {
    if (_categories.isEmpty) {
      final now = DateTime.now();
      // Add default expense categories
      final defaultExpenseCategories = [
        model.Category(
          name: 'Food & Dining',
          type: 'expense',
          color: '#FF6B6B',
          icon: 'restaurant',
          createdAt: now,
        ),
        model.Category(
          name: 'Transportation',
          type: 'expense',
          color: '#4ECDC4',
          icon: 'directions_car',
          createdAt: now,
        ),
        model.Category(
          name: 'Shopping',
          type: 'expense',
          color: '#45B7D1',
          icon: 'shopping_bag',
          createdAt: now,
        ),
        model.Category(
          name: 'Entertainment',
          type: 'expense',
          color: '#96CEB4',
          icon: 'movie',
          createdAt: now,
        ),
        model.Category(
          name: 'Bills & Utilities',
          type: 'expense',
          color: '#FFEAA7',
          icon: 'receipt',
          createdAt: now,
        ),
        model.Category(
          name: 'Healthcare',
          type: 'expense',
          color: '#DDA0DD',
          icon: 'local_hospital',
          createdAt: now,
        ),
        model.Category(
          name: 'Education',
          type: 'expense',
          color: '#98D8C8',
          icon: 'school',
          createdAt: now,
        ),
        model.Category(
          name: 'Other',
          type: 'expense',
          color: '#F7DC6F',
          icon: 'category',
          createdAt: now,
        ),
      ];

      // Add default income categories
      final defaultIncomeCategories = [
        model.Category(
          name: 'Salary',
          type: 'income',
          color: '#2ECC71',
          icon: 'work',
          createdAt: now,
        ),
        model.Category(
          name: 'Freelance',
          type: 'income',
          color: '#3498DB',
          icon: 'computer',
          createdAt: now,
        ),
        model.Category(
          name: 'Investment',
          type: 'income',
          color: '#9B59B6',
          icon: 'trending_up',
          createdAt: now,
        ),
        model.Category(
          name: 'Gift',
          type: 'income',
          color: '#E74C3C',
          icon: 'card_giftcard',
          createdAt: now,
        ),
        model.Category(
          name: 'Other Income',
          type: 'income',
          color: '#F39C12',
          icon: 'attach_money',
          createdAt: now,
        ),
      ];

      // Insert all default categories
      for (final category in [
        ...defaultExpenseCategories,
        ...defaultIncomeCategories,
      ]) {
        await addCategory(category);
      }
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
      await _databaseHelper.clearAllData();
      _categories.clear();
      notifyListeners();
      
      // Reinitialize with default categories
      await initializeDefaultCategories();
    } catch (e) {
      _setError('Failed to clear data: $e');
    } finally {
      _setLoading(false);
    }
  }
}
