import 'package:flutter/foundation.dart';
import '../models/category.dart' as models;
import '../repositories/repositories.dart';

class CategoryProvider with ChangeNotifier {
  CategoryProvider(this._repository);

  final CategoryRepository _repository;

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
      _categories = await _repository.getAll();
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
      await _repository.insert(category);
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
      await _repository.update(category);
      await loadCategories();
      return true;
    } catch (e) {
      _setError('Failed to update category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    _clearError();

    try {
      await _repository.delete(id);
      await loadCategories();
      return true;
    } catch (e) {
      _setError('Failed to delete category: $e');
      return false;
    }
  }

  Future<models.Category?> getCategoryByKey(int id) {
    return _repository.getById(id);
  }

  /// Synchronous lookup against the already-loaded list (used by the UI).
  models.Category? getCategoryById(int id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> initializeDefaultCategories() async {
    if (_categories.isNotEmpty) return;

    final now = DateTime.now();
    final defaultCategories = <models.Category>[
      // Income categories
      models.Category(name: 'Salary', type: 'income', color: '#4CAF50', icon: 'work', createdAt: now),
      models.Category(name: 'Investment', type: 'income', color: '#FF9800', icon: 'trending_up', createdAt: now),
      models.Category(name: 'Other Income', type: 'income', color: '#9C27B0', icon: 'attach_money', createdAt: now),
      // Expense categories
      models.Category(name: 'Food & Dining', type: 'expense', color: '#F44336', icon: 'restaurant', createdAt: now),
      models.Category(name: 'Transportation', type: 'expense', color: '#3F51B5', icon: 'directions_car', createdAt: now),
      models.Category(name: 'Shopping', type: 'expense', color: '#E91E63', icon: 'shopping_bag', createdAt: now),
      models.Category(name: 'Entertainment', type: 'expense', color: '#9C27B0', icon: 'movie', createdAt: now),
      models.Category(name: 'Bills & Utilities', type: 'expense', color: '#607D8B', icon: 'receipt', createdAt: now),
      models.Category(name: 'Healthcare', type: 'expense', color: '#4CAF50', icon: 'local_hospital', createdAt: now),
      models.Category(name: 'Education', type: 'expense', color: '#FF9800', icon: 'school', createdAt: now),
      models.Category(name: 'Other Expenses', type: 'expense', color: '#795548', icon: 'category', createdAt: now),
    ];

    try {
      for (final category in defaultCategories) {
        await _repository.insert(category);
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

  /// Resets in-memory state. Persistence is cleared via [AppRepositories].
  Future<void> clearAllData() async {
    _categories = [];
    notifyListeners();
  }
}
