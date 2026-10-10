import 'package:flutter/foundation.dart' show debugPrint;
import 'package:smart_spender/repositories/repositories.dart';
import 'demo_data_seeder.dart';

/// Dev-only sanity check that prints a summary of what's in the database.
Future<void> testDatabase(AppRepositories repositories) async {
  debugPrint('🚀 Testing SmartSpender Database...');

  try {
    final categories = await repositories.categories.getAll();
    debugPrint('\n📂 Categories: ${categories.length}');

    final transactions = await repositories.transactions.getAllWithCategoryInfo();
    debugPrint('💰 Transactions: ${transactions.length}');

    final budgets = await repositories.budgets.getAllWithCategoryInfo();
    debugPrint('📊 Budgets: ${budgets.length}');

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final monthlyIncome = await repositories.transactions
        .getTotalIncome(startDate: startOfMonth, endDate: endOfMonth);
    final monthlyExpenses = await repositories.transactions
        .getTotalExpenses(startDate: startOfMonth, endDate: endOfMonth);

    debugPrint('✅ Monthly totals for ${now.toIso8601String().substring(0, 7)}:');
    debugPrint('   - Income: R${monthlyIncome.toStringAsFixed(2)}');
    debugPrint('   - Expense: R${monthlyExpenses.toStringAsFixed(2)}');
    debugPrint('   - Balance: R${(monthlyIncome - monthlyExpenses).toStringAsFixed(2)}');

    debugPrint('\n🎉 Database test completed successfully!');
  } catch (e) {
    debugPrint('❌ Database test failed: $e');
  }
}

Future<void> seedDemoDataAndTest(AppRepositories repositories) async {
  debugPrint('🚀 Starting SmartSpender Demo Data Setup...');
  try {
    await seedDemoData(repositories);
    debugPrint('🧪 Running database tests with demo data...');
    await testDatabase(repositories);
    debugPrint('🎉 Demo data setup and testing completed successfully!');
  } catch (e) {
    debugPrint('❌ Error during demo data setup: $e');
  }
}
