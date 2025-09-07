import 'package:smart_spender/database/hive_helper.dart';
import 'package:smart_spender/models/category.dart';
import 'package:smart_spender/models/transaction.dart';
import 'package:smart_spender/models/budget.dart';
import 'demo_data_seeder.dart';

Future<void> testDatabase() async {
  print('🚀 Testing SmartSpender Database...');

  try {
    // Initialize Hive first
    await HiveHelper.initHive();

    // Test 1: Get categories
    print('\n📂 Testing Categories...');
    final categories = HiveHelper.getAllCategories();
    print('✅ Found ${categories.length} categories');

    // Print first few categories
    for (int i = 0; i < (categories.length > 3 ? 3 : categories.length); i++) {
      final category = categories[i];
      print('   - ${category.name} (${category.type}) ${category.icon ?? ''}');
    }

    // Test 2: Get transactions
    print('\n💰 Testing Transactions...');
    final allTransactions = HiveHelper.getAllTransactions();
    final transactions = allTransactions.take(5).toList();
    print('✅ Found ${transactions.length} recent transactions (of ${allTransactions.length} total)');

    for (int i = 0;
      i < (transactions.length > 3 ? 3 : transactions.length);
      i++
    ) {
      final transaction = transactions[i];
      print(
        '   - ${transaction.description}: ${transaction.displayAmount} (${transaction.date.toString().split(' ')[0]})',
      );
    }

    // Test 3: Get budgets
    print('\n📊 Testing Budgets...');
    final budgets = HiveHelper.getAllBudgets();
    print('✅ Found ${budgets.length} budgets');

    for (int i = 0; i < (budgets.length > 3 ? 3 : budgets.length); i++) {
      final budget = budgets[i];
      final category = HiveHelper.getCategory(budget.categoryKey);
      print(
        '   - ${category?.name}: R${budget.amount.toStringAsFixed(2)} (${budget.period})',
      );
    }

    // Test 4: Analytics
    print('\n📈 Testing Analytics...');
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
    
    print('✅ Monthly totals for ${now.toIso8601String().substring(0, 7)}:');
    print('   - Income: R${monthlyIncome.toStringAsFixed(2)}');
    print('   - Expense: R${monthlyExpenses.toStringAsFixed(2)}');
    print('   - Balance: R${balance.toStringAsFixed(2)}');

    // Test 5: Category totals
    final categoryTotals = HiveHelper.getExpensesByCategory(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );
    print('\n📊 Top expense categories this month:');
    
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (int i = 0; i < (sortedCategories.length > 3 ? 3 : sortedCategories.length); i++) {
      final entry = sortedCategories[i];
      print('   - ${entry.key}: R${entry.value.toStringAsFixed(2)}');
    }

    print('\n🎉 Database test completed successfully!');
  } catch (e) {
    print('❌ Database test failed: $e');
  }
}

Future<void> seedDemoDataAndTest() async {
  print('🚀 Starting SmartSpender Demo Data Setup...');
  print('');

  try {
    // First, seed the demo data
    await seedDemoData();

    print('');
    print('🧪 Running database tests with demo data...');

    // Then run the tests
    await testDatabase();

    print('');
    print('🎉 Demo data setup and testing completed successfully!');
    print('');
    print('Your SmartSpender app now includes:');
    print('• 18 realistic categories with icons and colors');
    print('• 6 months of varied transaction history');
    print('• Monthly budgets for major expense categories');
    print('• Realistic transaction amounts and descriptions');
    print('');
    print('You can now run your Flutter app to see all the demo data!');
  } catch (e) {
    print('❌ Error during demo data setup: $e');
  }
}
