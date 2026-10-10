import 'package:flutter/foundation.dart' show debugPrint;
import 'package:smart_spender/database/hive_helper.dart';
import 'demo_data_seeder.dart';

Future<void> testDatabase() async {
  debugPrint('🚀 Testing SmartSpender Database...');

  try {
    // Initialize Hive first
    await HiveHelper.initHive();

    // Test 1: Get categories
    debugPrint('\n📂 Testing Categories...');
    final categories = HiveHelper.getAllCategories();
    debugPrint('✅ Found ${categories.length} categories');

    // Print first few categories
    for (int i = 0; i < (categories.length > 3 ? 3 : categories.length); i++) {
      final category = categories[i];
      debugPrint('   - ${category.name} (${category.type}) ${category.icon ?? ''}');
    }

    // Test 2: Get transactions
    debugPrint('\n💰 Testing Transactions...');
    final allTransactions = HiveHelper.getAllTransactions();
    final transactions = allTransactions.take(5).toList();
    debugPrint('✅ Found ${transactions.length} recent transactions (of ${allTransactions.length} total)');

    for (int i = 0;
      i < (transactions.length > 3 ? 3 : transactions.length);
      i++
    ) {
      final transaction = transactions[i];
      debugPrint(
        '   - ${transaction.description}: ${transaction.displayAmount} (${transaction.date.toString().split(' ')[0]})',
      );
    }

    // Test 3: Get budgets
    debugPrint('\n📊 Testing Budgets...');
    final budgets = HiveHelper.getAllBudgets();
    debugPrint('✅ Found ${budgets.length} budgets');

    for (int i = 0; i < (budgets.length > 3 ? 3 : budgets.length); i++) {
      final budget = budgets[i];
      final category = HiveHelper.getCategory(budget.categoryKey);
      debugPrint(
        '   - ${category?.name}: R${budget.amount.toStringAsFixed(2)} (${budget.period})',
      );
    }

    // Test 4: Analytics
    debugPrint('\n📈 Testing Analytics...');
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final monthlyIncome = HiveHelper.getTotalIncome(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
    final monthlyExpenses = HiveHelper.getTotalExpenses(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
    final balance = monthlyIncome - monthlyExpenses;
    
    debugPrint('✅ Monthly totals for ${now.toIso8601String().substring(0, 7)}:');
    debugPrint('   - Income: R${monthlyIncome.toStringAsFixed(2)}');
    debugPrint('   - Expense: R${monthlyExpenses.toStringAsFixed(2)}');
    debugPrint('   - Balance: R${balance.toStringAsFixed(2)}');

    // Test 5: Category totals
    final categoryTotals = HiveHelper.getExpensesByCategory(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
    debugPrint('\n📊 Top expense categories this month:');
    
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (int i = 0; i < (sortedCategories.length > 3 ? 3 : sortedCategories.length); i++) {
      final entry = sortedCategories[i];
      debugPrint('   - ${entry.key}: R${entry.value.toStringAsFixed(2)}');
    }

    debugPrint('\n🎉 Database test completed successfully!');
  } catch (e) {
    debugPrint('❌ Database test failed: $e');
  }
}

Future<void> seedDemoDataAndTest() async {
  debugPrint('🚀 Starting SmartSpender Demo Data Setup...');
  debugPrint('');

  try {
    // First, seed the demo data
    await seedDemoData();

    debugPrint('');
    debugPrint('🧪 Running database tests with demo data...');

    // Then run the tests
    await testDatabase();

    debugPrint('');
    debugPrint('🎉 Demo data setup and testing completed successfully!');
    debugPrint('');
    debugPrint('Your SmartSpender app now includes:');
    debugPrint('• 18 realistic categories with icons and colors');
    debugPrint('• 6 months of varied transaction history');
    debugPrint('• Monthly budgets for major expense categories');
    debugPrint('• Realistic transaction amounts and descriptions');
    debugPrint('');
    debugPrint('You can now run your Flutter app to see all the demo data!');
  } catch (e) {
    debugPrint('❌ Error during demo data setup: $e');
  }
}
