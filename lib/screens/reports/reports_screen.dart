import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/currency.dart';
import '../../repositories/repositories.dart';
import '../../services/insights/insights_engine.dart';
import '../../theme/finance_colors.dart';
import '../../widgets/redesign/redesign.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _tabs = <FilterChipOption>[
    FilterChipOption(value: 'overview', label: 'Overview'),
    FilterChipOption(value: 'trends', label: 'Trends'),
    FilterChipOption(value: 'categories', label: 'Categories'),
    FilterChipOption(value: 'budget', label: 'Budget'),
    FilterChipOption(value: 'insights', label: 'Insights'),
  ];

  String _selectedTab = 'overview';
  String _selectedPeriod = 'This Month';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateDateRange();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: colorScheme.surface,
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FilterChipScroller(
              options: _tabs,
              selected: _selectedTab,
              onSelected: (value) => setState(() => _selectedTab = value),
            ),
          ),
          Expanded(child: _buildSelectedTab()),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTab) {
      case 'trends':
        return _buildTrendsTab();
      case 'categories':
        return _buildCategoriesTab();
      case 'budget':
        return _buildBudgetTab();
      case 'insights':
        return _buildInsightsTab();
      case 'overview':
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildInsightsTab() {
    final symbol = context.watch<SettingsController>().currencySymbol;
    final repositories = context.read<AppRepositories>();
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Insight>>(
      future:
          InsightsEngine(repositories).buildInsights(currencySymbol: symbol),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final insights = snapshot.data ?? const <Insight>[];
        if (insights.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 64, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                const Text('No insights yet'),
                const Text('Add more transactions to unlock insights'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: insights.length,
          itemBuilder: (context, index) {
            final insight = insights[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoBanner(
                icon: _insightIcon(insight.kind),
                tone: insight.kind == InsightKind.warning
                    ? InfoBannerTone.warning
                    : InfoBannerTone.info,
                messageWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      insight.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insight.detail,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _insightIcon(InsightKind kind) {
    switch (kind) {
      case InsightKind.positive:
        return '✅';
      case InsightKind.warning:
        return '⚠️';
      case InsightKind.info:
        return '💡';
    }
  }

  Widget _buildOverviewTab() {
    final symbol = context.watch<SettingsController>().currencySymbol;
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
        final savingsRate =
            totalIncome > 0 ? (balance / totalIncome * 100) : 0.0;
        final finance = Theme.of(context).financeColors;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MiniStatRow(
                tiles: [
                  MiniStatTile(
                    label: 'Income',
                    value: CurrencyFormatter.format(symbol, totalIncome),
                    icon: Icons.trending_up,
                    iconColor: finance.income,
                    valueColor: finance.income,
                  ),
                  MiniStatTile(
                    label: 'Expenses',
                    value: CurrencyFormatter.format(symbol, totalExpenses),
                    icon: Icons.trending_down,
                    iconColor: finance.expense,
                    valueColor: finance.expense,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MiniStatRow(
                tiles: [
                  MiniStatTile(
                    label: 'Balance',
                    value: CurrencyFormatter.format(symbol, balance),
                    icon: balance >= 0
                        ? Icons.account_balance_wallet
                        : Icons.warning,
                    iconColor:
                        balance >= 0 ? finance.info : finance.warning,
                    valueColor:
                        balance >= 0 ? finance.info : finance.warning,
                  ),
                  MiniStatTile(
                    label: 'Savings rate',
                    value: '${savingsRate.toStringAsFixed(1)}%',
                    icon: Icons.savings,
                    iconColor: savingsRate >= 20
                        ? finance.income
                        : savingsRate >= 10
                            ? finance.warning
                            : finance.expense,
                    valueColor: savingsRate >= 20
                        ? finance.income
                        : savingsRate >= 10
                            ? finance.warning
                            : finance.expense,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ReportCard(
                title: 'Quick stats',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(
                      'Total transactions',
                      '${transactions.length}',
                    ),
                    _buildStatRow(
                      'Average transaction',
                      transactions.isNotEmpty
                          ? CurrencyFormatter.format(
                              symbol,
                              transactions.fold(
                                    0.0,
                                    (sum, t) => sum + t.amount,
                                  ) /
                                  transactions.length,
                            )
                          : CurrencyFormatter.format(symbol, 0),
                    ),
                    _buildStatRow(
                      'Largest expense',
                      transactions
                              .where((t) => t.type == 'expense')
                              .isNotEmpty
                          ? CurrencyFormatter.format(
                              symbol,
                              transactions
                                  .where((t) => t.type == 'expense')
                                  .map((t) => t.amount)
                                  .reduce((a, b) => a > b ? a : b),
                            )
                          : CurrencyFormatter.format(symbol, 0),
                    ),
                    _buildStatRow(
                      'Days tracked',
                      '${_endDate.difference(_startDate).inDays + 1}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendsTab() {
    final symbol = context.watch<SettingsController>().currencySymbol;
    final finance = Theme.of(context).financeColors;
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ReportCard(
                title: 'Income vs expenses',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _LegendDot(color: finance.income),
                        const SizedBox(width: 8),
                        const Text('Income'),
                        const SizedBox(width: 24),
                        _LegendDot(color: finance.expense),
                        const SizedBox(width: 8),
                        const Text('Expenses'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: _buildTrendChart(transactionProvider, symbol),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ReportCard(
                title: 'Trend insights',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildTrendInsights(transactionProvider, symbol),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    final symbol = context.watch<SettingsController>().currencySymbol;
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer2<TransactionProvider, CategoryProvider>(
      builder: (context, transactionProvider, categoryProvider, child) {
        final categorySpending =
            transactionProvider.getCategoryExpenseSummary();

        if (categorySpending.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline,
                    size: 64, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                const Text('No expense data available'),
                const Text('Add some transactions to see category breakdown'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ReportCard(
                title: 'Spending by category',
                child: SizedBox(
                  height: 220,
                  child: _buildCategoryPieChart(
                    categorySpending,
                    categoryProvider,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ReportCard(
                title: 'Category details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: categorySpending.entries.map((entry) {
                    final category =
                        categoryProvider.getCategoryById(entry.key);
                    final percentage = (entry.value /
                        categorySpending.values.fold(0.0, (a, b) => a + b) *
                        100);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          _LegendDot(
                            color: category != null
                                ? categoryColorFromHex(category.color)
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(category?.name ?? 'Unknown'),
                          ),
                          Text('${percentage.toStringAsFixed(1)}%'),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.format(symbol, entry.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetTab() {
    final symbol = context.watch<SettingsController>().currencySymbol;
    final colorScheme = Theme.of(context).colorScheme;
    final finance = Theme.of(context).financeColors;
    return Consumer3<BudgetProvider, TransactionProvider, CategoryProvider>(
      builder:
          (context, budgetProvider, transactionProvider, categoryProvider, child) {
        final activeBudgets = budgetProvider.activeBudgets;

        if (activeBudgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assessment_outlined,
                    size: 64, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                const Text('No active budgets'),
                const Text('Create budgets to track your spending goals'),
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
              final status = isOverBudget
                  ? BudgetStatus.over
                  : (progress >= 0.9
                      ? BudgetStatus.nearing
                      : BudgetStatus.onTrack);

              return _ReportCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category?.name ?? 'Unknown Category',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusBadge(
                          status: status,
                          label: budget.period.toUpperCase(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${CurrencyFormatter.format(symbol, spent)} spent',
                        ),
                        Text(
                          '${CurrencyFormatter.format(symbol, budget.amount)} budget',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FinanceProgressBar(value: progress, status: status),
                    const SizedBox(height: 6),
                    Text(
                      isOverBudget
                          ? 'Over budget by ${CurrencyFormatter.format(symbol, spent - budget.amount)}'
                          : '${CurrencyFormatter.format(symbol, budget.amount - spent)} remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverBudget ? finance.expense : finance.income,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(
    TransactionProvider transactionProvider,
    String symbol,
  ) {
    final monthlyData = _getMonthlyTrendData(transactionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final finance = Theme.of(context).financeColors;

    if (monthlyData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart,
                size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            const Text('No data available'),
            Text('Add transactions to see trends',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final axisStyle = TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: colorScheme.outlineVariant, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(CurrencyFormatter.formatCompact(symbol, value),
                    style: axisStyle);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                final index = value.toInt();
                return Text(
                  index < months.length ? months[index] : '',
                  style: axisStyle,
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: monthlyData
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value['income']!))
                .toList(),
            isCurved: true,
            color: finance.income,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: monthlyData
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value['expense']!))
                .toList(),
            isCurved: true,
            color: finance.expense,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  List<Map<String, double>> _getMonthlyTrendData(
      TransactionProvider transactionProvider) {
    final now = DateTime.now();
    final monthlyData = <Map<String, double>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      final monthTransactions = transactionProvider.transactions.where((t) =>
          t.date.isAfter(month.subtract(const Duration(days: 1))) &&
          t.date.isBefore(nextMonth)).toList();

      final income = monthTransactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);

      final expense = monthTransactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      monthlyData.add({'income': income, 'expense': expense});
    }

    return monthlyData;
  }

  List<Widget> _buildTrendInsights(
    TransactionProvider transactionProvider,
    String symbol,
  ) {
    final monthlyData = _getMonthlyTrendData(transactionProvider);
    final finance = Theme.of(context).financeColors;
    final colorScheme = Theme.of(context).colorScheme;

    if (monthlyData.length < 2) {
      return [
        const Text('Need more data to show insights'),
        Text('Add transactions from multiple months',
            style: TextStyle(color: colorScheme.onSurfaceVariant)),
      ];
    }

    final insights = <Widget>[];

    // Calculate average monthly income/expense
    final avgIncome =
        monthlyData.map((m) => m['income']!).reduce((a, b) => a + b) /
            monthlyData.length;
    final avgExpense =
        monthlyData.map((m) => m['expense']!).reduce((a, b) => a + b) /
            monthlyData.length;

    // Net savings trend
    final netSavings = avgIncome - avgExpense;
    final savingsColor = netSavings >= 0 ? finance.income : finance.expense;
    final savingsIcon =
        netSavings >= 0 ? Icons.trending_up : Icons.trending_down;

    insights.add(
      Row(
        children: [
          Icon(savingsIcon, color: savingsColor, size: 20),
          const SizedBox(width: 8),
          Text('Average monthly ${netSavings >= 0 ? 'savings' : 'deficit'}: '),
          Text(
            CurrencyFormatter.format(symbol, netSavings.abs()),
            style: TextStyle(fontWeight: FontWeight.bold, color: savingsColor),
          ),
        ],
      ),
    );

    // Spending trend
    if (monthlyData.length >= 3) {
      final recentExpense = (monthlyData.last['expense']! +
              monthlyData[monthlyData.length - 2]['expense']!) /
          2;
      final olderExpense =
          (monthlyData.first['expense']! + monthlyData[1]['expense']!) / 2;
      final expenseChange =
          ((recentExpense - olderExpense) / olderExpense * 100);

      if (expenseChange.abs() > 5) {
        insights.add(const SizedBox(height: 8));
        insights.add(
          Row(
            children: [
              Icon(
                expenseChange > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                color: expenseChange > 0 ? finance.expense : finance.income,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Spending ${expenseChange > 0 ? 'increased' : 'decreased'} by '),
              Text(
                '${expenseChange.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: expenseChange > 0 ? finance.expense : finance.income,
                ),
              ),
              const Text(' recently'),
            ],
          ),
        );
      }
    }

    return insights.isEmpty
        ? [const Text('No significant trends detected')]
        : insights;
  }

  Widget _buildCategoryPieChart(
    Map<int, double> categorySpending,
    CategoryProvider categoryProvider,
  ) {
    final total = categorySpending.values.fold(0.0, (a, b) => a + b);
    final colorScheme = Theme.of(context).colorScheme;

    // fl_chart 1.x asserts that PieChartSectionData.value is > 0, so filter out
    // any zero/negative entries before building sections.
    final sections = categorySpending.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
      final category = categoryProvider.getCategoryById(entry.key);
      final percentage = total > 0 ? (entry.value / total * 100) : 0.0;

      return PieChartSectionData(
        color: category != null
            ? categoryColorFromHex(category.color)
            : colorScheme.onSurfaceVariant,
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 44,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        // Donut inner radius ~60% of the outer edge.
        centerSpaceRadius: 66,
        sectionsSpace: 2,
      ),
    );
  }
}

/// A styled report card matching the mockup `.m-card`, with an optional
/// uppercase section title.
class _ReportCard extends StatelessWidget {
  const _ReportCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            SectionHeader(title!, padding: const EdgeInsets.only(bottom: 10)),
          ],
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
