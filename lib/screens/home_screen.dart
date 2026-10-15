import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'transactions/transaction_list_screen.dart';
import 'transactions/add_transaction_screen.dart';
import 'categories/category_list_screen.dart';
import 'budgets/budget_list_screen.dart';
import 'reports/reports_screen.dart';
import 'recurring/recurring_list_screen.dart';
import 'settings/settings_screen.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../models/transaction.dart';
import '../utils/currency.dart';
import '../repositories/repositories.dart';
import '../theme/finance_colors.dart';
import '../widgets/logo_widget.dart';
import '../widgets/budget_alert_summary.dart';
import '../widgets/insight_highlight.dart';
import '../widgets/redesign/redesign.dart';
import '../debug_screen.dart';
import '../test_database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardTab(onSelectTab: _selectTab),
      const TransactionListScreen(),
      const CategoryListScreen(),
      const BudgetListScreen(),
      const ReportsScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: _NavEmoji('🏠'),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: _NavEmoji('🧾'),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: _NavEmoji('🏷️'),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: _NavEmoji('🎯'),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: _NavEmoji('📊'),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

/// A bottom-navigation icon rendered as an emoji glyph (to match the mobile
/// mockups, which use emoji for the nav items instead of Material icons).
class _NavEmoji extends StatelessWidget {
  const _NavEmoji(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Text(emoji, style: const TextStyle(fontSize: 20));
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, this.onSelectTab});

  /// Switches the host [HomeScreen] bottom navigation to the given tab index.
  final ValueChanged<int>? onSelectTab;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    // Load data when dashboard is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).loadTransactions();
        Provider.of<CategoryProvider>(context, listen: false).loadCategories();
        Provider.of<BudgetProvider>(context, listen: false).loadBudgets();
      }
    });
  }

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
        final repositories =
            Provider.of<AppRepositories>(context, listen: false);
        await repositories.clearAllData();

        // Clear data from providers and re-seed default categories
        if (context.mounted) {
          final categoryProvider =
              Provider.of<CategoryProvider>(context, listen: false);
          final transactionProvider =
              Provider.of<TransactionProvider>(context, listen: false);
          final budgetProvider =
              Provider.of<BudgetProvider>(context, listen: false);
          await transactionProvider.clearAllData();
          await budgetProvider.clearAllData();
          await categoryProvider.clearAllData();
          await categoryProvider.initializeDefaultCategories();
        }

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'All data cleared successfully! Default categories have been added.',
              ),
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

  /// Seeds realistic demo data after confirming (it replaces all existing
  /// data). Shows a loading dialog while seeding, then refreshes the providers.
  Future<void> _loadDemoData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Demo Data'),
        content: const Text(
          'This replaces all existing data with realistic demo data:\n\n'
          '• 18 categories with icons and colours\n'
          '• 6 months of transaction history\n'
          '• Monthly budgets for major categories\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Load Demo Data'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Loading indicator.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Creating demo data...'),
          ],
        ),
      ),
    );

    try {
      final repositories =
          Provider.of<AppRepositories>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      final budgetProvider =
          Provider.of<BudgetProvider>(context, listen: false);
      await seedDemoDataAndTest(repositories);

      await categoryProvider.loadCategories();
      await transactionProvider.loadTransactions();
      await budgetProvider.loadBudgets();

      if (context.mounted) {
        Navigator.of(context).pop(); // close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo data created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating demo data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _refreshData() {
    if (mounted) {
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).loadTransactions();
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
      Provider.of<BudgetProvider>(context, listen: false).loadBudgets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const LogoWidget(width: 100, height: 100),
        centerTitle: true,
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'refresh':
                  _refreshData();
                  break;
                case 'debug':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DebugScreen(),
                    ),
                  );
                  break;
                case 'recurring':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RecurringListScreen(),
                    ),
                  );
                  break;
                case 'load_demo':
                  await _loadDemoData(context);
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
                value: 'recurring',
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 20),
                    SizedBox(width: 8),
                    Text('Recurring'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, size: 20),
                    SizedBox(width: 8),
                    Text('View Database'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'load_demo',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 20),
                    SizedBox(width: 8),
                    Text('Load Demo Data'),
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
        builder: (context, transactionProvider, categoryProvider,
            budgetProvider, child) {
          // Calculate current month data
          final now = DateTime.now();
          final currentMonthIncome = transactionProvider.getMonthlyIncome(now);
          final currentMonthExpenses =
              transactionProvider.getMonthlyExpenses(now);
          final balance = currentMonthIncome - currentMonthExpenses;
          final symbol = context.watch<SettingsController>().currencySymbol;
          final savingsPercentage = currentMonthIncome > 0
              ? ((balance / currentMonthIncome) * 100).round()
              : 0;

          final financeColors = Theme.of(context).financeColors;

          final heroPills = <String>[
            balance >= 0
                ? '$savingsPercentage% of income saved'
                : '${savingsPercentage.abs()}% over budget',
          ];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Financial overview caption (mockup `.muted` line).
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                child: Text(
                  'Financial Overview · $currentMonth',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // Gradient "Money left over" / "Over Budget" hero.
              GradientHero(
                icon: balance >= 0
                    ? Icons.account_balance_wallet
                    : Icons.warning_amber_rounded,
                label: balance >= 0 ? 'Money left over' : 'Over Budget',
                amount: CurrencyFormatter.format(symbol, balance.abs()),
                pills: heroPills,
              ),
              const SizedBox(height: 14),

              // 2-up income / expense tiles.
              MiniStatRow(
                tiles: [
                  MiniStatTile(
                    label: 'Income',
                    value: CurrencyFormatter.format(symbol, currentMonthIncome),
                    icon: Icons.trending_up,
                    iconColor: financeColors.income,
                    valueColor: financeColors.income,
                  ),
                  MiniStatTile(
                    label: 'Expenses',
                    value:
                        CurrencyFormatter.format(symbol, currentMonthExpenses),
                    icon: Icons.trending_down,
                    iconColor: financeColors.expense,
                    valueColor: financeColors.expense,
                  ),
                ],
              ),

              // Budget alerts summary banner (renders nothing when all ok).
              // Alerts are actionable and sit above the informational insight.
              BudgetAlertSummary(
                onTap: () => widget.onSelectTab?.call(3),
              ),

              // Top offline insight highlight (renders nothing when none).
              // Tapping switches to the Reports tab (index 4), whose
              // "Insights" tab shows the full list.
              InsightHighlight(
                onTap: () => widget.onSelectTab?.call(4),
              ),

              const SizedBox(height: 14),

              // Quick actions.
              const SectionHeader('Quick actions'),
              MiniStatRow(
                tiles: [
                  MiniStatTile(
                    label: 'Add income',
                    icon: Icons.add,
                    iconColor: financeColors.income,
                    centred: true,
                    onTap: () => _navigateToAddTransaction(context, 'income'),
                  ),
                  MiniStatTile(
                    label: 'Add expense',
                    icon: Icons.remove,
                    iconColor: financeColors.expense,
                    centred: true,
                    onTap: () => _navigateToAddTransaction(context, 'expense'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Recent transactions.
              const SectionHeader('Recent'),
              _buildRecentCard(
                context,
                transactionProvider,
                categoryProvider,
                symbol,
                financeColors,
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToAddTransaction(BuildContext context, String type) async {
    // Navigate to transactions tab and open add transaction screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
    );

    // Refresh data when returning from add transaction screen
    if (result == true && context.mounted) {
      Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).loadTransactions();
      Provider.of<CategoryProvider>(context, listen: false).loadCategories();
      Provider.of<BudgetProvider>(context, listen: false).loadBudgets();
    }
  }

  /// Human-friendly relative day label for a transaction date.
  String _relativeDay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM').format(date);
  }

  Widget _buildRecentCard(
    BuildContext context,
    TransactionProvider transactionProvider,
    CategoryProvider categoryProvider,
    String symbol,
    FinanceColors financeColors,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final recent = transactionProvider.getRecentTransactions(limit: 5);

    if (recent.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 44,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add income or an expense to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < recent.length; i++) {
      final Transaction txn = recent[i];
      final category = txn.categoryId != null
          ? categoryProvider.getCategoryById(txn.categoryId!)
          : null;
      final colorHex = txn.categoryColor ?? category?.color;
      final iconName = txn.categoryIcon ?? category?.icon;
      final categoryName =
          txn.categoryName ?? category?.name ?? txn.displayCategoryName;
      final subtitle = '$categoryName · ${_relativeDay(txn.date)}';

      if (i > 0) rows.add(FinanceListRow.divider(context));
      rows.add(
        FinanceListRow(
          title: (txn.description != null && txn.description!.isNotEmpty)
              ? txn.description!
              : categoryName,
          subtitle: subtitle,
          colorHex: colorHex,
          iconName: iconName,
          amountText: CurrencyFormatter.formatSigned(
            symbol,
            txn.amount,
            isIncome: txn.isIncome,
          ),
          amountColor:
              txn.isIncome ? financeColors.income : financeColors.expense,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: rows),
      ),
    );
  }
}
