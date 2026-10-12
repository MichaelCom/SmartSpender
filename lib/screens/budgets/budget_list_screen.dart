import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'add_budget_screen.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/budget.dart';
import '../../utils/currency.dart';
import '../../utils/budget_alerts.dart';
import '../../services/insights/forecast_engine.dart';
import '../../theme/finance_colors.dart';
import '../../widgets/redesign/redesign.dart';

class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  bool _showActiveBudgets = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

      await Future.wait([
        budgetProvider.loadBudgets(),
        categoryProvider.loadCategories(),
        transactionProvider.loadTransactions(),
        Provider.of<RecurringProvider>(context, listen: false).loadRecurring(),
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Are you sure you want to delete the budget for ${budget.categoryName ?? 'this category'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && budget.key != null) {
      if (!mounted) return;
      final budgetProvider = Provider.of<BudgetProvider>(context, listen: false);
      final success = await budgetProvider.deleteBudget(budget.key!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Budget deleted successfully' : 'Failed to delete budget',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  double _getSpentAmount(Budget budget) {
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final transactions = transactionProvider.getTransactionsByCategory(budget.categoryKey);

    // Filter transactions within budget period
    final relevantTransactions = transactions.where((transaction) {
      return transaction.date.isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
             transaction.date.isBefore(budget.endDate.add(const Duration(days: 1))) &&
             transaction.type == 'expense';
    });

    return relevantTransactions.fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  BudgetStatus _mapStatus(BudgetAlertStatus status) {
    if (status.isExceeded) return BudgetStatus.over;
    if (status.isNearing) return BudgetStatus.nearing;
    return BudgetStatus.onTrack;
  }

  /// Builds the muted projection line for a budget card, or null when it should
  /// be suppressed (fewer than 4 days of the month elapsed — run-rate is noise).
  Widget? _buildProjectionLine(Budget budget, String symbol) {
    final now = DateTime.now();
    if (now.day < 4) return null;

    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final recurringProvider =
        Provider.of<RecurringProvider>(context, listen: false);
    final finance = Theme.of(context).financeColors;
    final colorScheme = Theme.of(context).colorScheme;

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final monthTransactions = transactionProvider.transactions
        .where((t) =>
            !t.date.isBefore(monthStart) && !t.date.isAfter(monthEnd))
        .toList();

    final forecast = ForecastEngine.forecastBudget(
      budget: budget,
      monthTransactions: monthTransactions,
      recurring: recurringProvider.recurring,
      now: now,
    );

    final exceed = forecast.projectedToExceed;
    final color = exceed ? finance.warning : colorScheme.onSurfaceVariant;
    final label = exceed
        ? 'Projected: ${CurrencyFormatter.format(symbol, forecast.projectedTotal)} / '
            '${CurrencyFormatter.format(symbol, budget.amount)} '
            '(over by ${CurrencyFormatter.format(symbol, forecast.projectedOverBy)})'
        : 'Projected: ${CurrencyFormatter.format(symbol, forecast.projectedTotal)} / '
            '${CurrencyFormatter.format(symbol, budget.amount)}';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.insights_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: exceed ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final finance = Theme.of(context).financeColors;
    final settings = context.watch<SettingsController>();
    final symbol = settings.currencySymbol;
    final threshold = settings.budgetAlertThreshold;
    final monthLabel = DateFormat('MMMM').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: Icon(_showActiveBudgets ? Icons.history : Icons.access_time),
            onPressed: () {
              setState(() {
                _showActiveBudgets = !_showActiveBudgets;
              });
            },
            tooltip: _showActiveBudgets ? 'Show All Budgets' : 'Show Active Budgets',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer3<BudgetProvider, CategoryProvider, TransactionProvider>(
              builder: (context, budgetProvider, categoryProvider, transactionProvider, child) {
                final budgets = _showActiveBudgets
                    ? budgetProvider.activeBudgets
                    : budgetProvider.budgets;

                if (budgets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showActiveBudgets
                              ? 'No active budgets found'
                              : 'No budgets created yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Create your first budget to start tracking your spending limits',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddBudgetScreen(),
                              ),
                            );
                            if (result == true) {
                              _loadData();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Budget'),
                        ),
                      ],
                    ),
                  );
                }

                // Totals for the 2-up mini stat row.
                double totalBudgeted = 0;
                double totalSpent = 0;
                for (final b in budgets) {
                  totalBudgeted += b.amount;
                  totalSpent += _getSpentAmount(b);
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      MiniStatRow(
                        tiles: [
                          MiniStatTile(
                            label: 'Budgeted',
                            value: CurrencyFormatter.format(symbol, totalBudgeted),
                          ),
                          MiniStatTile(
                            label: 'Spent',
                            value: CurrencyFormatter.format(symbol, totalSpent),
                            valueColor: finance.expense,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SectionHeader('$monthLabel budgets'),
                      for (final budget in budgets)
                        _buildBudgetCard(
                          context,
                          budget,
                          symbol,
                          threshold,
                          colorScheme,
                          finance,
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddBudgetScreen(),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    Budget budget,
    String symbol,
    int threshold,
    ColorScheme colorScheme,
    FinanceColors finance,
  ) {
    final spentAmount = _getSpentAmount(budget);
    final alertStatus = BudgetAlerts.evaluate(
      spent: spentAmount,
      limit: budget.amount,
      thresholdPercent: threshold,
    );
    final status = _mapStatus(alertStatus);
    final progress = budget.amount > 0
        ? (spentAmount / budget.amount).clamp(0.0, 1.0)
        : 0.0;
    final percentUsed = budget.amount > 0
        ? (spentAmount / budget.amount * 100).round()
        : 0;
    final isOverBudget = alertStatus.isExceeded;
    final remainingAmount = budget.amount - spentAmount;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: colorScheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: icon chip, name + "spent of limit", status badge, menu.
            Row(
              children: [
                CategoryIconChip(
                  colorHex: budget.categoryColor,
                  iconName: budget.categoryIcon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.categoryName ?? 'Unknown Category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${CurrencyFormatter.format(symbol, spentAmount)} of '
                        '${CurrencyFormatter.format(symbol, budget.amount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: status),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddBudgetScreen(budget: budget),
                          ),
                        );
                        if (result == true) {
                          _loadData();
                        }
                        break;
                      case 'delete':
                        _deleteBudget(budget);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar.
            FinanceProgressBar(value: progress, status: status),
            const SizedBox(height: 7),

            // % used + remaining / over.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$percentUsed% used',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  isOverBudget
                      ? '${CurrencyFormatter.format(symbol, -remainingAmount)} over'
                      : '${CurrencyFormatter.format(symbol, remainingAmount)} left',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOverBudget
                        ? finance.expense
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // Muted forecast projection line (suppressed in the first few days
            // of the month).
            ?_buildProjectionLine(budget, symbol),

            // Description.
            if (budget.description != null && budget.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                budget.description!,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
