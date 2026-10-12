import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'add_recurring_screen.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/recurring_transaction.dart';
import '../../utils/currency.dart';
import '../../theme/finance_colors.dart';
import '../../widgets/redesign/redesign.dart';

class RecurringListScreen extends StatefulWidget {
  const RecurringListScreen({super.key});

  @override
  State<RecurringListScreen> createState() => _RecurringListScreenState();
}

class _RecurringListScreenState extends State<RecurringListScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final recurringProvider =
          Provider.of<RecurringProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      await Future.wait([
        recurringProvider.loadRecurring(),
        categoryProvider.loadCategories(),
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading recurring transactions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openForm({RecurringTransaction? recurring}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddRecurringScreen(recurring: recurring),
      ),
    );
    if (result == true && mounted) {
      await _loadData();
      // Refresh transactions in case any were generated/affected elsewhere.
      if (mounted) {
        Provider.of<TransactionProvider>(context, listen: false)
            .loadTransactions();
      }
    }
  }

  Future<void> _deleteRecurring(RecurringTransaction rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Transaction'),
        content: const Text(
          'Delete this recurring rule?\n\n'
          'Already-generated transactions will be kept (they will no longer '
          'be linked to this rule).',
        ),
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

    if (confirmed == true && rule.id != null && mounted) {
      final provider = Provider.of<RecurringProvider>(context, listen: false);
      final success = await provider.deleteRecurring(rule.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Recurring transaction deleted'
                  : 'Failed to delete recurring transaction',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return frequency;
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final symbol = context.watch<SettingsController>().currencySymbol;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add recurring',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<RecurringProvider>(
              builder: (context, provider, child) {
                final rules = provider.recurring;
                if (rules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.repeat,
                            size: 64, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        const Text(
                          'No recurring transactions yet',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a rule to automate repeating income or expenses',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final now = DateTime.now();
                final activeCount =
                    rules.where((r) => r.isActive(now)).length;

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      InfoBanner(
                        icon: '🔁',
                        message:
                            '$activeCount active ${activeCount == 1 ? 'rule' : 'rules'} · auto-added on their due date',
                      ),
                      const SizedBox(height: 14),
                      const SectionHeader('Active rules'),
                      _RulesCard(
                        rules: rules,
                        symbol: symbol,
                        now: now,
                        frequencyLabel: _frequencyLabel,
                        formatDate: _formatDate,
                        onTapRule: (rule) => _openForm(recurring: rule),
                        onEditRule: (rule) => _openForm(recurring: rule),
                        onDeleteRule: _deleteRecurring,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Card wrapping the list of recurring-rule [FinanceListRow]s.
class _RulesCard extends StatelessWidget {
  const _RulesCard({
    required this.rules,
    required this.symbol,
    required this.now,
    required this.frequencyLabel,
    required this.formatDate,
    required this.onTapRule,
    required this.onEditRule,
    required this.onDeleteRule,
  });

  final List<RecurringTransaction> rules;
  final String symbol;
  final DateTime now;
  final String Function(String) frequencyLabel;
  final String Function(DateTime) formatDate;
  final ValueChanged<RecurringTransaction> onTapRule;
  final ValueChanged<RecurringTransaction> onEditRule;
  final ValueChanged<RecurringTransaction> onDeleteRule;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final finance = Theme.of(context).financeColors;

    final children = <Widget>[];
    for (var i = 0; i < rules.length; i++) {
      if (i > 0) children.add(FinanceListRow.divider(context));
      final rule = rules[i];
      final isIncome = rule.isIncome;
      final active = rule.isActive(now);
      final nextDue = rule.nextDueDate(now);
      final subtitle = active
          ? '🔁 ${frequencyLabel(rule.frequency)} · next ${formatDate(nextDue)}'
          : '🔁 ${frequencyLabel(rule.frequency)} · inactive';

      children.add(
        FinanceListRow(
          title: rule.description?.isNotEmpty == true
              ? rule.description!
              : rule.displayCategoryName,
          subtitle: subtitle,
          colorHex: rule.categoryColor,
          iconName: rule.categoryIcon,
          onTap: () => onTapRule(rule),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CurrencyFormatter.formatSigned(
                  symbol,
                  rule.amount,
                  isIncome: isIncome,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isIncome ? finance.income : finance.expense,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEditRule(rule);
                  } else if (value == 'delete') {
                    onDeleteRule(rule);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
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
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}
