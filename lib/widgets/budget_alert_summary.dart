import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/budget.dart';
import '../providers/budget_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/budget_alerts.dart';

/// Compact dashboard banner summarising budgets that need attention.
///
/// Reads [BudgetProvider], [TransactionProvider] and the
/// [SettingsController.budgetAlertThreshold] via `context.watch`, evaluates each
/// active budget with [BudgetAlerts.evaluate], and shows counts like
/// `"2 over · 1 nearing"`. Renders [SizedBox.shrink] when every budget is ok.
///
/// Tapping the banner invokes [onTap] (the host typically switches to the
/// Budgets tab).
class BudgetAlertSummary extends StatelessWidget {
  const BudgetAlertSummary({super.key, this.onTap});

  /// Called when the banner is tapped. No-op when null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final threshold = context.watch<SettingsController>().budgetAlertThreshold;

    var exceededCount = 0;
    var nearingCount = 0;

    for (final budget in budgetProvider.activeBudgets) {
      final spent = _spentForBudget(budget, transactionProvider);
      final status = BudgetAlerts.evaluate(
        spent: spent,
        limit: budget.amount,
        thresholdPercent: threshold,
      );
      switch (status.level) {
        case BudgetAlertLevel.exceeded:
          exceededCount++;
          break;
        case BudgetAlertLevel.nearing:
          nearingCount++;
          break;
        case BudgetAlertLevel.ok:
          break;
      }
    }

    if (exceededCount == 0 && nearingCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final bool hasExceeded = exceededCount > 0;
    final Color accent = hasExceeded ? Colors.red : Colors.amber.shade800;
    final IconData icon =
        hasExceeded ? Icons.error_outline : Icons.warning_amber_rounded;

    final parts = <String>[];
    if (exceededCount > 0) parts.add('$exceededCount over');
    if (nearingCount > 0) parts.add('$nearingCount nearing');
    final label = parts.join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget alerts',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Spent amount for [budget]'s category within its period. Mirrors the logic
  /// used by the budget list screen (expenses in [startDate, endDate]).
  double _spentForBudget(
    Budget budget,
    TransactionProvider transactionProvider,
  ) {
    final transactions =
        transactionProvider.getTransactionsByCategory(budget.categoryKey);
    final relevant = transactions.where((transaction) {
      return transaction.type == 'expense' &&
          transaction.date
              .isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
          transaction.date
              .isBefore(budget.endDate.add(const Duration(days: 1)));
    });
    return relevant.fold(0.0, (sum, transaction) => sum + transaction.amount);
  }
}
