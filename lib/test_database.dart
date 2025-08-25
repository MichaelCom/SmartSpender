import 'package:smart_spender/database/database_helper.dart';
import 'package:smart_spender/models/category.dart';
import 'package:smart_spender/models/transaction.dart';
import 'package:smart_spender/models/budget.dart';
import 'demo_data_seeder.dart';

Future<void> testDatabase() async {
  print('🚀 Testing SmartSpender Database...');

  try {
    final dbHelper = DatabaseHelper();

    // Test 1: Get categories
    print('\n📂 Testing Categories...');
    final categories = await dbHelper.getCategories();
    print('✅ Found ${categories.length} categories');

    // Print first few categories
    for (int i = 0; i < (categories.length > 3 ? 3 : categories.length); i++) {
      final category = categories[i];
      print('   - ${category.name} (${category.type}) ${category.icon ?? ''}');
    }

    // Test 2: Get transactions
    print('\n💰 Testing Transactions...');
    final transactions = await dbHelper.getTransactions(limit: 5);
    print('✅ Found ${transactions.length} recent transactions');

    for (
      int i = 0;
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
    final budgets = await dbHelper.getBudgets();
    print('✅ Found ${budgets.length} budgets');

    for (int i = 0; i < (budgets.length > 3 ? 3 : budgets.length); i++) {
      final budget = budgets[i];
      final category = await dbHelper.getCategoryById(budget.categoryId);
      print(
        '   - ${category?.name}: \$${budget.amount.toStringAsFixed(2)} (${budget.period})',
      );
    }

    // Test 4: Analytics
    print('\n📈 Testing Analytics...');
    final currentMonth = DateTime.now().toIso8601String().substring(
      0,
      7,
    ); // YYYY-MM
    final monthlyTotals = await dbHelper.getMonthlyTotals(currentMonth);
    print('✅ Monthly totals for $currentMonth:');
    print(
      '   - Income: \$${monthlyTotals['income']?.toStringAsFixed(2) ?? '0.00'}',
    );
    print(
      '   - Expense: \$${monthlyTotals['expense']?.toStringAsFixed(2) ?? '0.00'}',
    );
    print(
      '   - Balance: \$${monthlyTotals['balance']?.toStringAsFixed(2) ?? '0.00'}',
    );

    // Test 5: Category totals
    final categoryTotals = await dbHelper.getCategoryTotals(
      startDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      ).toIso8601String().split('T')[0],
      type: 'expense',
    );
    print('\n📊 Top expense categories this month:');
    for (
      int i = 0;
      i < (categoryTotals.length > 3 ? 3 : categoryTotals.length);
      i++
    ) {
      final categoryTotal = categoryTotals[i];
      print(
        '   - ${categoryTotal['name']}: \$${(categoryTotal['total'] as num).toStringAsFixed(2)}',
      );
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
