import 'package:flutter/material.dart';

/// A small statistic tile: optional tinted icon box, a label, and a value.
///
/// Mirrors the mockup `.mini`. Used in 2-up rows on the dashboard, budgets and
/// reports screens. Wrap two in a [MiniStatRow] for the standard side-by-side
/// layout. Optionally tappable (e.g. the dashboard quick-action tiles).
class MiniStatTile extends StatelessWidget {
  const MiniStatTile({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.iconColor,
    this.valueColor,
    this.centred = false,
    this.onTap,
  });

  /// Caption beneath/above the value, e.g. `Income`.
  final String label;

  /// The formatted statistic. When null, only [label] (and [icon]) show —
  /// used for quick-action tiles.
  final String? value;

  /// Optional glyph shown in a tinted rounded box.
  final IconData? icon;

  /// Tint for the icon box; defaults to the colour scheme primary.
  final Color? iconColor;

  /// Optional override for the value text colour (e.g. expense red).
  final Color? valueColor;

  /// When true, contents are centred (quick-action style).
  final bool centred;

  /// Optional tap handler; makes the whole tile a button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tint = iconColor ?? colorScheme.primary;

    final content = Column(
      crossAxisAlignment:
          centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: tint),
          ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (value != null) ...[
          const SizedBox(height: 2),
          Text(
            value!,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: valueColor ?? colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(width: double.infinity, child: content),
        ),
      ),
    );
  }
}

/// Lays out two (or more) [MiniStatTile]s in an equal-width row with the
/// standard 12px gutter.
class MiniStatRow extends StatelessWidget {
  const MiniStatRow({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 12));
      children.add(Expanded(child: tiles[i]));
    }
    // IntrinsicHeight lets the tiles share a common (content-derived) height
    // via CrossAxisAlignment.stretch WITHOUT requiring a bounded height from
    // the parent — safe inside a SingleChildScrollView/Column.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
