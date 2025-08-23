import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/budget_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'This Month';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _updateDateRange();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'This Week':
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _endDate = now;
        break;
      case 'This Month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = lastMonth;
        _endDate = DateTime(now.year, now.month, 0);
        break;
      case 'This Year':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = now;
        break;
    }
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
                _updateDateRange();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'This Week', child: Text('This Week')),
              const PopupMenuItem(
                value: 'This Month',
                child: Text('This Month'),
              ),
              const PopupMenuItem(
                value: 'Last Month',
                child: Text('Last Month'),
              ),
              const PopupMenuItem(value: 'This Year', child: Text('This Year')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedPeriod, style: const TextStyle(fontSize: 14)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: 'Overview'),
            Tab(icon: Icon(Icons.trending_up), text: 'Trends'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
            Tab(icon: Icon(Icons.assessment), text: 'Budget'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTrendsTab(),
          _buildCategoriesTab(),
          _buildBudgetTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer2<TransactionProvider, CategoryProvider>(
      builder: (context, transactionProvider, categoryProvider, child) {
        final transactions = transactionProvider.getTransactionsByDateRange(
          _startDate,
          _endDate,
        );
        final totalIncome = transactions
            .where((t) => t.type == 'income')
            .fold(0.0, (sum, t) => sum + t.amount);
        final totalExpenses = transactions
            .where((t) => t.type == 'expense')
            .fold(0.0, (sum, t) => sum + t.amount);
        final balance = totalIncome - totalExpenses;
        final savingsRate = totalIncome > 0
            ? (balance / totalIncome * 100)
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_selectedPeriod Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Income',
                              '\R${totalIncome.toStringAsFixed(2)}',
                              Icons.trending_up,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              'Expenses',
                              '\R${totalExpenses.toStringAsFixed(2)}',
                              Icons.trending_down,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Balance',
                              '\R${balance.toStringAsFixed(2)}',
                              balance >= 0
                                  ? Icons.account_balance_wallet
                                  : Icons.warning,
                              balance >= 0 ? Colors.blue : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              'Savings Rate',
                              '${savingsRate.toStringAsFixed(1)}%',
                              Icons.savings,
                              savingsRate >= 20
                                  ? Colors.green
                                  : savingsRate >= 10
                                  ? Colors.orange
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quick Stats
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Stats',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        'Total Transactions',
                        '${transactions.length}',
                      ),
                      _buildStatRow(
                        'Average Transaction',
                        transactions.isNotEmpty
                            ? '\R${(transactions.fold(0.0, (sum, t) => sum + t.amount) / transactions.length).toStringAsFixed(2)}'
                            : '\R0.00',
                      ),
                      _buildStatRow(
                        'Largest Expense',
                        transactions
                                .where((t) => t.type == 'expense')
                                .isNotEmpty
                            ? '\R${transactions.where((t) => t.type == 'expense').map((t) => t.amount).reduce((a, b) => a > b ? a : b).toStringAsFixed(2)}'
                            : '\R0.00',
                      ),
                      _buildStatRow(
                        'Days Tracked',
                        '${_endDate.difference(_startDate).inDays + 1}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendsTab() {
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Income vs Expenses Trend',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildTrendChart(transactionProvider),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coming Soon',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Monthly comparison charts\n• Spending velocity\n• Seasonal patterns',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    return Consumer2<TransactionProvider, CategoryProvider>(
      builder: (context, transactionProvider, categoryProvider, child) {
        final categorySpending = transactionProvider
            .getCategoryExpenseSummary();

        if (categorySpending.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No expense data available'),
                Text('Add some transactions to see category breakdown'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spending by Category',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildCategoryPieChart(
                          categorySpending,
                          categoryProvider,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...categorySpending.entries.map((entry) {
                        final category = categoryProvider.getCategoryById(
                          entry.key,
                        );
                        final percentage =
                            (entry.value /
                            categorySpending.values.fold(0.0, (a, b) => a + b) *
                            100);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: category != null
                                      ? _hexToColor(category.color ?? '#FF6B6B')
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(category?.name ?? 'Unknown'),
                              ),
                              Text('${percentage.toStringAsFixed(1)}%'),
                              const SizedBox(width: 8),
                              Text('\R${entry.value.toStringAsFixed(2)}'),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetTab() {
    return Consumer3<BudgetProvider, TransactionProvider, CategoryProvider>(
      builder: (context, budgetProvider, transactionProvider, categoryProvider, child) {
        final activeBudgets = budgetProvider.activeBudgets;

        if (activeBudgets.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assessment_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No active budgets'),
                Text('Create budgets to track your spending goals'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: activeBudgets.map((budget) {
              final category = categoryProvider.getCategoryById(
                budget.categoryId,
              );
              final spent = transactionProvider.getTotalAmountByCategory(
                budget.categoryId,
              );
              final progress = budgetProvider.calculateBudgetProgress(
                budget,
                spent,
              );
              final isOverBudget = budgetProvider.isBudgetExceeded(
                budget,
                spent,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category?.name ?? 'Unknown Category',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            budget.period.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('\R${spent.toStringAsFixed(2)} spent'),
                          Text('\R${budget.amount.toStringAsFixed(2)} budget'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOverBudget
                            ? 'Over budget by \R${(spent - budget.amount).toStringAsFixed(2)}'
                            : '\R${(budget.amount - spent).toStringAsFixed(2)} remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverBudget ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTrendChart(TransactionProvider transactionProvider) {
    // Simplified chart - in a real implementation, you'd build actual chart data
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Trend Chart'),
            Text('Coming Soon', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart(
    Map<int, double> categorySpending,
    CategoryProvider categoryProvider,
  ) {
    final total = categorySpending.values.fold(0.0, (a, b) => a + b);

    return PieChart(
      PieChartData(
        sections: categorySpending.entries.map((entry) {
          final category = categoryProvider.getCategoryById(entry.key);
          final percentage = (entry.value / total * 100);

          return PieChartSectionData(
            color: category != null
                ? _hexToColor(category.color ?? '#FF6B6B')
                : Colors.grey,
            value: entry.value,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }
}
