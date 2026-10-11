import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'add_recurring_screen.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/recurring_transaction.dart';
import '../../utils/currency.dart';

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

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final symbol = context.watch<SettingsController>().currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No recurring transactions yet',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a rule to automate repeating income or expenses',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: rules.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      final isIncome = rule.isIncome;
                      final now = DateTime.now();
                      final active = rule.isActive(now);
                      final nextDue = rule.nextDueDate(now);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: (isIncome
                                    ? Colors.green
                                    : Colors.red)
                                .withValues(alpha: 0.1),
                            child: Icon(
                              isIncome
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            rule.description?.isNotEmpty == true
                                ? rule.description!
                                : rule.displayCategoryName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${_frequencyLabel(rule.frequency)} · ${rule.displayCategoryName}',
                              ),
                              Text(
                                active
                                    ? 'Next due: ${_formatDate(nextDue)}'
                                    : 'Inactive',
                                style: TextStyle(
                                  color: active
                                      ? Colors.grey[600]
                                      : Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
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
                                  fontWeight: FontWeight.bold,
                                  color: isIncome ? Colors.green : Colors.red,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openForm(recurring: rule);
                                  } else if (value == 'delete') {
                                    _deleteRecurring(rule);
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
                                        Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _openForm(recurring: rule),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}
