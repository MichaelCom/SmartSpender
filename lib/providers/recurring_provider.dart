import 'package:flutter/foundation.dart';
import '../models/recurring_transaction.dart';
import '../repositories/repositories.dart';

class RecurringProvider with ChangeNotifier {
  RecurringProvider(this._repository);

  final RecurringTransactionRepository _repository;

  List<RecurringTransaction> _recurring = [];
  bool _isLoading = false;
  String? _error;

  List<RecurringTransaction> get recurring => _recurring;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<RecurringTransaction> get activeRecurring {
    final now = DateTime.now();
    return _recurring.where((r) => r.isActive(now)).toList();
  }

  Future<void> loadRecurring() async {
    _setLoading(true);
    _clearError();

    try {
      _recurring = await _repository.getAll();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load recurring transactions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addRecurring(RecurringTransaction recurring) async {
    _clearError();

    try {
      await _repository.insert(recurring);
      await loadRecurring();
      return true;
    } catch (e) {
      _setError('Failed to add recurring transaction: $e');
      return false;
    }
  }

  Future<bool> updateRecurring(RecurringTransaction recurring) async {
    _clearError();

    try {
      await _repository.update(recurring);
      await loadRecurring();
      return true;
    } catch (e) {
      _setError('Failed to update recurring transaction: $e');
      return false;
    }
  }

  Future<bool> deleteRecurring(int id) async {
    _clearError();

    try {
      await _repository.delete(id);
      await loadRecurring();
      return true;
    } catch (e) {
      _setError('Failed to delete recurring transaction: $e');
      return false;
    }
  }

  Future<RecurringTransaction?> getRecurringById(int id) {
    return _repository.getById(id);
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
    _recurring = [];
    notifyListeners();
  }
}
