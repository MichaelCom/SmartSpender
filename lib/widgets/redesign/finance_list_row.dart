import 'package:flutter/material.dart';

import 'category_icon_chip.dart';

/// A single finance list row: leading category icon chip, title + subtitle, and
/// a trailing signed amount.
///
/// Mirrors the mockup `.m-row`. Used by the transactions, categories, budgets
/// and recurring list screens. The row does not draw its own divider — callers
/// place rows inside a card and separate them (e.g. with [FinanceListRow.divider]
/// or a `Column` of rows), matching the mockups where dividers sit between rows
/// but not after the last.
class FinanceListRow extends StatelessWidget {
  const FinanceListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.colorHex,
    this.iconName,
    this.amountText,
    this.amountColor,
    this.trailing,
    this.onTap,
    this.subtitleWidget,
  });

  /// Primary label, e.g. a merchant or category name.
  final String title;

  /// Optional secondary line, e.g. `Groceries · Today`. Ignored when
  /// [subtitleWidget] is provided.
  final String? subtitle;

  /// Rich subtitle override (e.g. a row with an anomaly flag). Takes precedence
  /// over [subtitle].
  final Widget? subtitleWidget;

  /// Category colour hex for the leading chip.
  final String? colorHex;

  /// Category icon name for the leading chip.
  final String? iconName;

  /// Pre-formatted trailing amount, e.g. `− R 642.80`. Ignored when [trailing]
  /// is provided.
  final String? amountText;

  /// Colour for [amountText]; defaults to the on-surface colour.
  final Color? amountColor;

  /// Custom trailing widget (e.g. amount + overflow menu). Takes precedence
  /// over [amountText].
  final Widget? trailing;

  /// Optional tap handler for the whole row.
  final VoidCallback? onTap;

  /// A hairline divider sized to sit between rows inside a card.
  static Widget divider(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Widget? sub = subtitleWidget ??
        (subtitle != null
            ? Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null);

    final Widget? trailWidget = trailing ??
        (amountText != null
            ? Text(
                amountText!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: amountColor ?? colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            : null);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        children: [
          CategoryIconChip(colorHex: colorHex, iconName: iconName),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 1),
                  sub,
                ],
              ],
            ),
          ),
          if (trailWidget != null) ...[
            const SizedBox(width: 10),
            trailWidget,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: row,
    );
  }
}
