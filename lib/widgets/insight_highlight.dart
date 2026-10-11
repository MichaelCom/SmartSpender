import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../repositories/repositories.dart';
import '../services/insights/insights_engine.dart';

/// Compact dashboard card surfacing the single most important offline insight.
///
/// Reads the top insight from [InsightsEngine.topInsight] (async) via a
/// [FutureBuilder], rendering an icon coloured by [Insight.kind] plus its
/// title/detail. Tapping invokes [onTap] (the host typically switches to the
/// Reports tab). Renders [SizedBox.shrink] when there is no insight.
class InsightHighlight extends StatelessWidget {
  const InsightHighlight({super.key, this.onTap});

  /// Called when the card is tapped. No-op when null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final repositories = context.read<AppRepositories>();
    final symbol = context.watch<SettingsController>().currencySymbol;

    return FutureBuilder<Insight?>(
      future: InsightsEngine(repositories).topInsight(currencySymbol: symbol),
      builder: (context, snapshot) {
        final insight = snapshot.data;
        if (insight == null) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final accent = _accentFor(insight.kind);
        final icon = _iconFor(insight.kind);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.detail,
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
      },
    );
  }

  static Color _accentFor(InsightKind kind) {
    switch (kind) {
      case InsightKind.positive:
        return Colors.green;
      case InsightKind.warning:
        return Colors.amber.shade800;
      case InsightKind.info:
        return Colors.blue;
    }
  }

  static IconData _iconFor(InsightKind kind) {
    switch (kind) {
      case InsightKind.positive:
        return Icons.check_circle_outline;
      case InsightKind.warning:
        return Icons.warning_amber_rounded;
      case InsightKind.info:
        return Icons.lightbulb_outline;
    }
  }
}
