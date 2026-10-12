import 'package:flutter/material.dart';

import '../../theme/finance_colors.dart';

/// The budget health state, driving both [StatusBadge] and [FinanceProgressBar]
/// colours.
enum BudgetStatus {
  /// Under the alert threshold.
  onTrack,

  /// At/above the alert threshold but not yet over 100%.
  nearing,

  /// Over 100% of the budgeted amount.
  over,
}

/// A small pill badge indicating budget health.
///
/// Mirrors the mockup `.badge` variants (`.b-over`, `.b-near`, `.b-ok`). Colour
/// and label are derived from [status]; pass [label] to override the text.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final BudgetStatus status;

  /// Optional label override; defaults to "Over" / "Nearing" / "On track".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final finance = Theme.of(context).financeColors;
    final colorScheme = Theme.of(context).colorScheme;

    late final Color bg;
    late final Color fg;
    late final String text;

    switch (status) {
      case BudgetStatus.over:
        bg = finance.expense.withValues(alpha: 0.16);
        fg = finance.expense;
        text = label ?? 'Over';
        break;
      case BudgetStatus.nearing:
        bg = finance.warning.withValues(alpha: 0.20);
        fg = finance.warning;
        text = label ?? 'Nearing';
        break;
      case BudgetStatus.onTrack:
        bg = colorScheme.primaryContainer;
        fg = colorScheme.onPrimaryContainer;
        text = label ?? 'On track';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

/// A rounded progress bar whose fill colour reflects a [BudgetStatus].
///
/// Mirrors the mockup `.m-prog`. [value] is clamped to 0..1; use [status] to
/// pick the fill colour (expense red when over, warning amber when nearing,
/// primary green when on track).
class FinanceProgressBar extends StatelessWidget {
  const FinanceProgressBar({
    super.key,
    required this.value,
    required this.status,
    this.height = 9,
  });

  final double value;
  final BudgetStatus status;
  final double height;

  @override
  Widget build(BuildContext context) {
    final finance = Theme.of(context).financeColors;
    final colorScheme = Theme.of(context).colorScheme;

    final Color fill;
    switch (status) {
      case BudgetStatus.over:
        fill = finance.expense;
        break;
      case BudgetStatus.nearing:
        fill = finance.warning;
        break;
      case BudgetStatus.onTrack:
        fill = colorScheme.primary;
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: colorScheme.surfaceContainerHigh,
        valueColor: AlwaysStoppedAnimation<Color>(fill),
      ),
    );
  }
}
