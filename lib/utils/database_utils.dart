import '../database/database_helper.dart';

class DatabaseUtils {
  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Clear all data from the database (transactions, budgets, categories)
  static Future<void> clearAllData() async {
    await _databaseHelper.clearAllData();
  }

  /// Clear only categories (this will also clear transactions and budgets due to foreign keys)
  static Future<void> clearAllCategories() async {
    await _databaseHelper.clearAllCategories();
  }

  /// Reset database to fresh state
  static Future<void> resetDatabase() async {
    try {
      // Clear all existing data
      await _databaseHelper.clearAllData();
      
      // Close the current database connection
      await _databaseHelper.close();
      
      // The next database access will recreate the database with fresh tables
      print('Database reset successfully');
    } catch (e) {
      print('Error resetting database: $e');
      rethrow;
    }
  }
}
