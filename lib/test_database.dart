// import 'package:smart_spender/database/database_helper.dart';
// import 'package:smart_spender/models/category.dart';
// import 'package:smart_spender/models/transaction.dart';
// import 'package:smart_spender/models/budget.dart';

// Future<void> testDatabase() async {
//   print('🚀 Testing SmartSpender Database...');
  
//   try {
//     final dbHelper = DatabaseHelper();
    
//     // Test 1: Get default categories
//     print('\n📂 Testing Categories...');
//     final categories = await dbHelper.getCategories();
//     print('✅ Found ${categories.length} default categories');
    
//     // Print first few categories
//     for (int i = 0; i < (categories.length > 3 ? 3 : categories.length); i++) {
//       final category = Category.fromMap(categories[i]);
//       print('   - ${category.name} (${category.type})');
//     }
    
//     // Test 2: Add a test transaction
//     print('\n💰 Testing Transactions...');
//     if (categories.isNotEmpty) {
//       final firstCategory = categories.first;
//       final testTransaction = {
//         'amount': 25.50,
//         'description': 'Test coffee purchase',
//         'category_id': firstCategory['id'],
//         'date': DateTime.now().toIso8601String().split('T')[0],
//         'type': 'expense',
//       };
      
//       final transactionId = await dbHelper.insertTransaction(testTransaction);
//       print('✅ Added test transaction with ID: $transactionId');
      
//       // Get transactions
//       final transactions = await dbHelper.getTransactionsWithCategories(limit: 5);
//       print('✅ Found ${transactions.length} transactions');
      
//       if (transactions.isNotEmpty) {
//         final transaction = Transaction.fromMap(transactions.first);
//         print('   - ${transaction.description}: ${transaction.displayAmount}');
//       }
//     }
    
//     // Test 3: Add a test budget
//     print('\n📊 Testing Budgets...');
//     if (categories.isNotEmpty) {
//       final expenseCategories = categories.where((c) => c['type'] == 'expense').toList();
//       if (expenseCategories.isNotEmpty) {
//         final category = expenseCategories.first;
//         final now = DateTime.now();
//         final testBudget = {
//           'category_id': category['id'],
//           'amount': 200.0,
//           'period': 'monthly',
//           'start_date': DateTime(now.year, now.month, 1).toIso8601String().split('T')[0],
//           'end_date': DateTime(now.year, now.month + 1, 0).toIso8601String().split('T')[0],
//         };
        
//         final budgetId = await dbHelper.insertBudget(testBudget);
//         print('✅ Added test budget with ID: $budgetId');
        
//         // Get budgets
//         final budgets = await dbHelper.getBudgetsWithCategories();
//         print('✅ Found ${budgets.length} budgets');
        
//         if (budgets.isNotEmpty) {
//           final budget = Budget.fromMap(budgets.first);
//           print('   - ${budget.categoryName}: ${budget.displayAmount} (${budget.period})');
//         }
//       }
//     }
    
//     // Test 4: Analytics
//     print('\n📈 Testing Analytics...');
//     final currentMonth = DateTime.now().toIso8601String().substring(0, 7); // YYYY-MM
//     final monthlyTotals = await dbHelper.getMonthlyTotals(currentMonth);
//     print('✅ Monthly totals for $currentMonth:');
//     print('   - Income: \$${monthlyTotals['income']?.toStringAsFixed(2) ?? '0.00'}');
//     print('   - Expense: \$${monthlyTotals['expense']?.toStringAsFixed(2) ?? '0.00'}');
//     print('   - Balance: \$${monthlyTotals['balance']?.toStringAsFixed(2) ?? '0.00'}');
    
//     print('\n🎉 Database test completed successfully!');
    
//   } catch (e) {
//     print('❌ Database test failed: $e');
//   }
// }
