import 'package:flutter/material.dart';

/// A single option in a [FilterChipScroller].
class FilterChipOption {
  const FilterChipOption({required this.value, required this.label, this.icon});

  /// The value reported to `onSelected` when this chip is tapped.
  final String value;

  /// Display label, e.g. `Groceries` or `All`.
  final String label;

  /// Optional leading emoji/glyph string shown before the label (mockups use
  /// emoji here, e.g. `🛒`). Kept as a string so callers can pass an emoji.
  final String? icon;
}

/// A horizontally-scrolling row of choice chips.
///
/// Mirrors the mockup `.chips` scroller used by Transactions (filter), Reports
/// (section tabs), and the forms (category / frequency pickers). Single-select:
/// the chip whose value equals [selected] is highlighted with the primary
/// container colour.
class FilterChipScroller extends StatelessWidget {
  const FilterChipScroller({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.only(bottom: 4),
  });

  final List<FilterChipOption> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(
                options[i].icon != null
                    ? '${options[i].icon} ${options[i].label}'
                    : options[i].label,
              ),
              selected: options[i].value == selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: options[i].value == selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              backgroundColor: colorScheme.surfaceContainerHigh,
              selectedColor: colorScheme.primaryContainer,
              side: BorderSide(
                color: options[i].value == selected
                    ? Colors.transparent
                    : colorScheme.outlineVariant,
              ),
              onSelected: (_) => onSelected(options[i].value),
            ),
          ],
        ],
      ),
    );
  }
}
