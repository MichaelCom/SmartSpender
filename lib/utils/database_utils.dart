import '../database/hive_helper.dart';

class DatabaseUtils {
  /// Clear all data from the database (transactions, budgets, categories)
  static Future<void> clearAllData() async {
    await HiveHelper.clearAllData();
  }

  /// Clear only categories (this will also clear transactions and budgets due to cascade delete)
  static Future<void> clearAllCategories() async {
    // Get all categories and delete them (this will cascade delete related data)
    final categories = HiveHelper.getAllCategories();
    for (final category in categories) {
      if (category.key != null) {
        await HiveHelper.deleteCategory(category.key!);
      }
    }
  }

  /// Reset database to fresh state
  static Future<void> resetDatabase() async {
    try {
      // Clear all existing data
      await HiveHelper.clearAllData();
      
      print('Database reset successfully');
    } catch (e) {
      print('Error resetting database: $e');
      rethrow;
    }
  }
}
