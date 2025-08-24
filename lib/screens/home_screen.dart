import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'transactions/transaction_list_screen.dart';
import 'transactions/add_transaction_screen.dart';
import 'categories/category_list_screen.dart';
import 'budgets/budget_list_screen.dart';
import 'reports/reports_screen.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../utils/database_utils.dart';
import '../widgets/logo_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardTab(),
    const TransactionListScreen(),
    const CategoryListScreen(),
    const BudgetListScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Budgets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  Future<void> _clearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to clear all data? This will delete:\n\n'
          '• All transactions\n'
          '• All budgets\n'
          '• All categories\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Clearing data...'),
              ],
            ),
          ),
        );

        // Clear data from database
        await DatabaseUtils.clearAllData();

        // Clear data from providers
        if (context.mounted) {
          await Provider.of<CategoryProvider>(context, listen: false).clearAllData();
          await Provider.of<TransactionProvider>(context, listen: false).clearAllData();
          await Provider.of<BudgetProvider>(context, listen: false).clearAllData();
        }

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data cleared successfully! Default categories have been added.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        // Close loading dialog if still open
        if (context.mounted) {
          Navigator.of(context).pop();
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing data: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    
    return Scaffold(
      appBar: AppBar(
        title: const LogoWidget(width: 60, height: 60),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  // Refresh all providers
                  Provider.of<CategoryProvider>(context, listen: false).loadCategories();
                  Provider.of<TransactionProvider>(context, listen: false).loadTransactions();
                  Provider.of<BudgetProvider>(context, listen: false).loadBudgets();
                  break;
                case 'clear_data':
                  await _clearAllData(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Refresh Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_data',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Data', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer3<TransactionProvider, CategoryProvider, BudgetProvider>(
        builder: (context, transactionProvider, categoryProvider, budgetProvider, child) {
          // Calculate current month data
          final now = DateTime.now();
          final currentMonthIncome = transactionProvider.getMonthlyIncome(now);
          final currentMonthExpenses = transactionProvider.getMonthlyExpenses(now);
          final balance = currentMonthIncome - currentMonthExpenses;
          final savingsPercentage = currentMonthIncome > 0 
              ? ((balance / currentMonthIncome) * 100).round()
              : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial Overview',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentMonth,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Main Financial Summary
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Income and Expenses Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildFinancialCard(
                                'Total Income',
                                '\$${currentMonthIncome.toStringAsFixed(2)}',
                                Icons.trending_up,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFinancialCard(
                                'Total Expenses',
                                '\$${currentMonthExpenses.toStringAsFixed(2)}',
                                Icons.trending_down,
                                Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Money Left Over - Main Focus
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: balance >= 0 
                                  ? [Colors.blue.shade400, Colors.blue.shade600]
                                  : [Colors.orange.shade400, Colors.orange.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (balance >= 0 ? Colors.blue : Colors.orange).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                balance >= 0 
                                    ? Icons.account_balance_wallet
                                    : Icons.warning,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                balance >= 0 ? 'Money Left Over' : 'Over Budget',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${balance.abs().toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  balance >= 0 
                                      ? '$savingsPercentage% of income saved'
                                      : '${savingsPercentage.abs()}% over budget',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        context,
                        'Add Income',
                        Icons.add_circle,
                        Colors.green,
                        () => _navigateToAddTransaction(context, 'income'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionCard(
                        context,
                        'Add Expense',
                        Icons.remove_circle,
                        Colors.red,
                        () => _navigateToAddTransaction(context, 'expense'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Categories
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Top Categories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to categories tab
                        DefaultTabController.of(context)?.animateTo(2);
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTopCategoriesList(transactionProvider, categoryProvider),
                const SizedBox(height: 24),

                // Monthly Breakdown
                Text(
                  'This Month Breakdown',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildMonthlyBreakdown(currentMonthIncome, currentMonthExpenses, balance),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showQuickAddDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddTransaction(BuildContext context, String type) {
    // Navigate to transactions tab and open add transaction screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddTransactionScreen(),
      ),
    );
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  IconData _getIconData(String iconName) {
    const Map<String, IconData> iconMap = {
      'category': Icons.category,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'shopping_bag': Icons.shopping_bag,
      'movie': Icons.movie,
      'receipt': Icons.receipt,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'work': Icons.work,
      'computer': Icons.computer,
      'trending_up': Icons.trending_up,
      'card_giftcard': Icons.card_giftcard,
      'attach_money': Icons.attach_money,
      'home': Icons.home,
      'fitness_center': Icons.fitness_center,
      'local_gas_station': Icons.local_gas_station,
      'phone': Icons.phone,
      'wifi': Icons.wifi,
      'pets': Icons.pets,
      'child_care': Icons.child_care,
    };
    return iconMap[iconName] ?? Icons.category;
  }

  Widget _buildFinancialCard(
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCategoriesList(TransactionProvider transactionProvider, CategoryProvider categoryProvider) {
    // Get category spending summary
    final categorySpending = transactionProvider.getCategoryExpenseSummary();
    
    if (categorySpending.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.category_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              const Text(
                'No expenses yet',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Start adding transactions to see your top categories',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Sort categories by spending amount and take top 4
    final sortedCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(4).toList();

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topCategories.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = topCategories[index];
          final category = categoryProvider.getCategoryById(entry.key);
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: category != null 
                  ? _hexToColor(category.color ?? '#FF6B6B').withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              child: Icon(
                category != null 
                    ? _getIconData(category.icon ?? 'category')
                    : Icons.category,
                color: category != null 
                    ? _hexToColor(category.color ?? '#FF6B6B')
                    : Colors.grey,
                size: 20,
              ),
            ),
            title: Text(category?.name ?? 'Unknown Category'),
            trailing: Text(
              '\$${entry.value.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlyBreakdown(double income, double expenses, double balance) {
    final progressValue = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final savingsPercentage = income > 0 ? ((balance / income) * 100).round() : 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Income vs Expenses'),
                Text(
                  balance >= 0 
                      ? '$savingsPercentage% saved'
                      : '${savingsPercentage.abs()}% over budget',
                  style: TextStyle(
                    color: balance >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.green.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                progressValue > 1.0 ? Colors.red : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent: \$${expenses.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  balance >= 0 
                      ? 'Remaining: \$${balance.toStringAsFixed(2)}'
                      : 'Over: \$${balance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick Add',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToAddTransaction(context, 'income');
                    },
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    label: const Text('Add Income'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToAddTransaction(context, 'expense');
                    },
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
