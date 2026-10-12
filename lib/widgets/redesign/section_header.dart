import 'package:flutter/material.dart';

/// An uppercase, muted section label.
///
/// Mirrors the mockup `.sec-title` used above lists and groups
/// (e.g. "QUICK ACTIONS", "OCTOBER BUDGETS", "RECENT").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.padding});

  final String label;

  /// Optional padding override; defaults to the mockup's `4px 2px 10px`.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
