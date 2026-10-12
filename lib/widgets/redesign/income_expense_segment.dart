import 'package:flutter/material.dart';

import '../../theme/finance_colors.dart';

/// A two-option segmented toggle for choosing Expense vs Income.
///
/// Mirrors the mockup `.seg`: the selected segment is tinted expense-red or
/// income-green and raised onto the surface colour; the unselected segment is
/// muted. Value is `'expense'` or `'income'`, matching the stored transaction /
/// category / recurring `type` field.
class IncomeExpenseSegment extends StatelessWidget {
  const IncomeExpenseSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Either `'expense'` or `'income'`.
  final String value;

  /// Called with `'expense'` or `'income'` when a segment is tapped.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: '− Expense',
              selected: value == 'expense',
              selectedColor: Theme.of(context).financeColors.expense,
              onTap: () => onChanged('expense'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _Segment(
              label: '＋ Income',
              selected: value == 'income',
              selectedColor: Theme.of(context).financeColors.income,
              onTap: () => onChanged('income'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      elevation: selected ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? selectedColor : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
