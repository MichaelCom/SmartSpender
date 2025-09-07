import 'dart:math';
import 'database/hive_helper.dart';
import 'models/category.dart';
import 'models/transaction.dart';
import 'models/budget.dart';

class DemoDataSeeder {
  final Random _random = Random();

  // Demo categories with icons and colors
  final List<Map<String, dynamic>> _expenseCategories = [
    {'name': 'Food & Dining', 'icon': '🍽️', 'color': '#FF6B6B'},
    {'name': 'Transportation', 'icon': '🚗', 'color': '#4ECDC4'},
    {'name': 'Shopping', 'icon': '🛍️', 'color': '#45B7D1'},
    {'name': 'Entertainment', 'icon': '🎬', 'color': '#96CEB4'},
    {'name': 'Bills & Utilities', 'icon': '💡', 'color': '#FFEAA7'},
    {'name': 'Healthcare', 'icon': '🏥', 'color': '#DDA0DD'},
    {'name': 'Education', 'icon': '📚', 'color': '#98D8C8'},
    {'name': 'Travel', 'icon': '✈️', 'color': '#F7DC6F'},
    {'name': 'Fitness & Sports', 'icon': '🏋️', 'color': '#BB8FCE'},
    {'name': 'Home & Garden', 'icon': '🏠', 'color': '#85C1E9'},
    {'name': 'Personal Care', 'icon': '💄', 'color': '#F8C471'},
    {'name': 'Gifts & Donations', 'icon': '🎁', 'color': '#82E0AA'},
  ];

  final List<Map<String, dynamic>> _incomeCategories = [
    {'name': 'Salary', 'icon': '💰', 'color': '#2ECC71'},
    {'name': 'Freelance', 'icon': '💻', 'color': '#27AE60'},
    {'name': 'Investment Returns', 'icon': '📈', 'color': '#229954'},
    {'name': 'Side Business', 'icon': '🏪', 'color': '#1E8449'},
    {'name': 'Rental Income', 'icon': '🏘️', 'color': '#196F3D'},
    {'name': 'Bonus', 'icon': '🎯', 'color': '#145A32'},
  ];

  // Sample transaction descriptions for each category
  final Map<String, List<String>> _transactionDescriptions = {
    'Food & Dining': [
      'Lunch at downtown cafe',
      'Grocery shopping at Whole Foods',
      'Pizza delivery',
      'Coffee with friends',
      'Dinner at Italian restaurant',
      'Fast food drive-through',
      'Farmers market vegetables',
      'Takeout Chinese food',
      'Breakfast at diner',
      'Ice cream shop',
    ],
    'Transportation': [
      'Gas station fill-up',
      'Uber ride to airport',
      'Monthly bus pass',
      'Car maintenance',
      'Parking meter',
      'Taxi fare',
      'Train ticket',
      'Car insurance payment',
      'Oil change',
      'Subway card refill',
    ],
    'Shopping': [
      'New clothes at mall',
      'Amazon online order',
      'Electronics store purchase',
      'Bookstore visit',
      'Home improvement supplies',
      'Pharmacy items',
      'Sporting goods',
      'Jewelry purchase',
      'Shoes from outlet',
      'Gift for friend',
    ],
    'Entertainment': [
      'Movie theater tickets',
      'Concert tickets',
      'Streaming service subscription',
      'Video game purchase',
      'Bowling night',
      'Mini golf',
      'Museum admission',
      'Theater show',
      'Amusement park',
      'Comedy club',
    ],
    'Bills & Utilities': [
      'Electric bill',
      'Internet service',
      'Phone bill',
      'Water utility',
      'Gas bill',
      'Trash collection',
      'Cable TV',
      'Home security',
      'Insurance premium',
      'Property tax',
    ],
    'Healthcare': [
      'Doctor visit copay',
      'Prescription medication',
      'Dental cleaning',
      'Eye exam',
      'Physical therapy',
      'Health insurance',
      'Vitamins and supplements',
      'Medical test',
      'Specialist consultation',
      'Emergency room visit',
    ],
    'Education': [
      'Online course fee',
      'Textbook purchase',
      'Workshop registration',
      'Certification exam',
      'Language lessons',
      'Professional development',
      'School supplies',
      'Library late fee',
      'Educational software',
      'Seminar attendance',
    ],
    'Travel': [
      'Flight booking',
      'Hotel reservation',
      'Car rental',
      'Travel insurance',
      'Vacation package',
      'Airport parking',
      'Tourist attraction',
      'Travel gear',
      'Foreign currency exchange',
      'Passport renewal',
    ],
    'Fitness & Sports': [
      'Gym membership',
      'Personal trainer session',
      'Yoga class',
      'Sports equipment',
      'Marathon registration',
      'Swimming pool pass',
      'Tennis court rental',
      'Fitness app subscription',
      'Protein supplements',
      'Athletic wear',
    ],
    'Home & Garden': [
      'Furniture purchase',
      'Garden supplies',
      'Home repair materials',
      'Cleaning supplies',
      'Kitchen appliance',
      'Paint and brushes',
      'Lawn care service',
      'Home decoration',
      'Tool rental',
      'Pest control',
    ],
    'Personal Care': [
      'Haircut and styling',
      'Spa treatment',
      'Skincare products',
      'Nail salon',
      'Massage therapy',
      'Beauty supplies',
      'Perfume purchase',
      'Barber shop',
      'Facial treatment',
      'Personal grooming',
    ],
    'Gifts & Donations': [
      'Birthday gift',
      'Charity donation',
      'Wedding present',
      'Holiday gifts',
      'Fundraiser contribution',
      'Religious offering',
      'Anniversary gift',
      'Baby shower gift',
      'Graduation present',
      'Thank you gift',
    ],
    'Salary': [
      'Monthly salary deposit',
      'Bi-weekly paycheck',
      'Overtime pay',
      'Holiday pay',
      'Commission payment',
    ],
    'Freelance': [
      'Web design project',
      'Consulting work',
      'Writing assignment',
      'Photography gig',
      'Tutoring session',
    ],
    'Investment Returns': [
      'Stock dividend',
      'Bond interest',
      'Mutual fund return',
      'Real estate profit',
      'Crypto gains',
    ],
    'Side Business': [
      'Online store sales',
      'Service provider payment',
      'Product sales',
      'Affiliate commission',
      'Business profit',
    ],
    'Rental Income': [
      'Monthly rent payment',
      'Property rental',
      'Room rental',
      'Equipment rental',
      'Storage rental',
    ],
    'Bonus': [
      'Performance bonus',
      'Year-end bonus',
      'Project completion bonus',
      'Sales bonus',
      'Holiday bonus',
    ],
  };

  Future<void> seedDemoData() async {
    print('🗑️ Clearing existing data...');
    await HiveHelper.clearAllData();

    print('📂 Creating categories...');
    final categoryKeys = await _createCategories();

    print('💰 Creating transactions...');
    await _createTransactions(categoryKeys);

    print('📊 Creating budgets...');
    await _createBudgets(categoryKeys);

    print('✅ Demo data seeding completed!');
  }

  Future<Map<String, List<int>>> _createCategories() async {
    final Map<String, List<int>> categoryKeys = {
      'expense': [],
      'income': [],
    };

    // Create expense categories
    for (final categoryData in _expenseCategories) {
      final category = Category(
        name: categoryData['name'],
        type: 'expense',
        icon: categoryData['icon'],
        color: categoryData['color'],
        createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
      );
      final key = await HiveHelper.insertCategory(category);
      categoryKeys['expense']!.add(key);
    }

    // Create income categories
    for (final categoryData in _incomeCategories) {
      final category = Category(
        name: categoryData['name'],
        type: 'income',
        icon: categoryData['icon'],
        color: categoryData['color'],
        createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
      );
      final key = await HiveHelper.insertCategory(category);
      categoryKeys['income']!.add(key);
    }

    return categoryKeys;
  }

  Future<void> _createTransactions(Map<String, List<int>> categoryKeys) async {
    final now = DateTime.now();
    final transactions = <Transaction>[];

    // Create transactions for the last 6 months
    for (int monthOffset = 0; monthOffset < 6; monthOffset++) {
      final monthDate = DateTime(now.year, now.month - monthOffset, 1);
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;

      // Create income transactions (2-4 per month)
      final incomeCount = 2 + _random.nextInt(3);
      for (int i = 0; i < incomeCount; i++) {
        final categoryKey = categoryKeys['income']![_random.nextInt(categoryKeys['income']!.length)];
        final category = HiveHelper.getCategory(categoryKey);
        final descriptions = _transactionDescriptions[category!.name] ?? ['Income'];
        
        final transaction = Transaction(
          amount: _generateIncomeAmount(category.name),
          description: descriptions[_random.nextInt(descriptions.length)],
          categoryKey: categoryKey,
          date: DateTime(monthDate.year, monthDate.month, 1 + _random.nextInt(daysInMonth)),
          type: 'income',
          createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(180))),
        );
        transactions.add(transaction);
      }

      // Create expense transactions (15-25 per month)
      final expenseCount = 15 + _random.nextInt(11);
      for (int i = 0; i < expenseCount; i++) {
        final categoryKey = categoryKeys['expense']![_random.nextInt(categoryKeys['expense']!.length)];
        final category = HiveHelper.getCategory(categoryKey);
        final descriptions = _transactionDescriptions[category!.name] ?? ['Expense'];
        
        final transaction = Transaction(
          amount: _generateExpenseAmount(category.name),
          description: descriptions[_random.nextInt(descriptions.length)],
          categoryKey: categoryKey,
          date: DateTime(monthDate.year, monthDate.month, 1 + _random.nextInt(daysInMonth)),
          type: 'expense',
          createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(180))),
        );
        transactions.add(transaction);
      }
    }

    // Insert all transactions
    for (final transaction in transactions) {
      await HiveHelper.insertTransaction(transaction);
    }

    print('   Created ${transactions.length} transactions');
  }

  Future<void> _createBudgets(Map<String, List<int>> categoryKeys) async {
    final now = DateTime.now();
    final budgets = <Budget>[];

    // Create monthly budgets for major expense categories
    final majorCategories = [
      'Food & Dining',
      'Transportation', 
      'Shopping',
      'Entertainment',
      'Bills & Utilities',
    ];

    for (final categoryName in majorCategories) {
      // Find the category key
      final categories = HiveHelper.getCategoriesByType('expense');
      final category = categories.firstWhere((cat) => cat.name == categoryName);
      
      if (category.key != null) {
        // Create budget for current month
        final startDate = DateTime(now.year, now.month, 1);
        final endDate = DateTime(now.year, now.month + 1, 0);
        
        final budget = Budget(
          categoryKey: category.key!,
          amount: _generateBudgetAmount(categoryName),
          period: 'monthly',
          startDate: startDate,
          endDate: endDate,
          createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
        );
        budgets.add(budget);

        // Create budget for next month
        final nextStartDate = DateTime(now.year, now.month + 1, 1);
        final nextEndDate = DateTime(now.year, now.month + 2, 0);
        
        final nextBudget = Budget(
          categoryKey: category.key!,
          amount: _generateBudgetAmount(categoryName),
          period: 'monthly',
          startDate: nextStartDate,
          endDate: nextEndDate,
          createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(30))),
        );
        budgets.add(nextBudget);
      }
    }

    // Insert all budgets
    for (final budget in budgets) {
      await HiveHelper.insertBudget(budget);
    }

    print('   Created ${budgets.length} budgets');
  }

  double _generateIncomeAmount(String categoryName) {
    switch (categoryName) {
      case 'Salary':
        return 3000.0 + _random.nextDouble() * 2000.0; // R3000-R5000
      case 'Freelance':
        return 500.0 + _random.nextDouble() * 1500.0; // R500-R2000
      case 'Investment Returns':
        return 100.0 + _random.nextDouble() * 500.0; // R100-R600
      case 'Side Business':
        return 200.0 + _random.nextDouble() * 800.0; // R200-R1000
      case 'Rental Income':
        return 800.0 + _random.nextDouble() * 700.0; // R800-R1500
      case 'Bonus':
        return 500.0 + _random.nextDouble() * 2000.0; // R500-R2500
      default:
        return 100.0 + _random.nextDouble() * 500.0;
    }
  }

  double _generateExpenseAmount(String categoryName) {
    switch (categoryName) {
      case 'Food & Dining':
        return 5.0 + _random.nextDouble() * 95.0; // R5-R100
      case 'Transportation':
        return 10.0 + _random.nextDouble() * 140.0; // R10-R150
      case 'Shopping':
        return 15.0 + _random.nextDouble() * 285.0; // R15-R300
      case 'Entertainment':
        return 8.0 + _random.nextDouble() * 92.0; // R8-R100
      case 'Bills & Utilities':
        return 50.0 + _random.nextDouble() * 450.0; // R50-R500
      case 'Healthcare':
        return 20.0 + _random.nextDouble() * 280.0; // R20-R300
      case 'Education':
        return 25.0 + _random.nextDouble() * 475.0; // R25-R500
      case 'Travel':
        return 100.0 + _random.nextDouble() * 900.0; // R100-R1000
      case 'Fitness & Sports':
        return 15.0 + _random.nextDouble() * 135.0; // R15-R150
      case 'Home & Garden':
        return 30.0 + _random.nextDouble() * 270.0; // R30-R300
      case 'Personal Care':
        return 10.0 + _random.nextDouble() * 140.0; // R10-R150
      case 'Gifts & Donations':
        return 20.0 + _random.nextDouble() * 180.0; // R20-R200
      default:
        return 10.0 + _random.nextDouble() * 90.0;
    }
  }

  double _generateBudgetAmount(String categoryName) {
    switch (categoryName) {
      case 'Food & Dining':
        return 400.0 + _random.nextDouble() * 200.0; // R400-R600
      case 'Transportation':
        return 200.0 + _random.nextDouble() * 300.0; // R200-R500
      case 'Shopping':
        return 300.0 + _random.nextDouble() * 200.0; // R300-R500
      case 'Entertainment':
        return 150.0 + _random.nextDouble() * 150.0; // R150-R300
      case 'Bills & Utilities':
        return 500.0 + _random.nextDouble() * 300.0; // R500-R800
      default:
        return 200.0 + _random.nextDouble() * 300.0;
    }
  }
}

// Standalone function to run the seeder
Future<void> seedDemoData() async {
  final seeder = DemoDataSeeder();
  await seeder.seedDemoData();
}
