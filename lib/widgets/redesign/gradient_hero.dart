import 'package:flutter/material.dart';

/// The dashboard gradient "hero" card.
///
/// Mirrors the mockup `.hero`: a rounded, primary→dark-green gradient panel
/// with a small label, a large tabular-figures amount, and a row of translucent
/// pills (e.g. savings %, trend). A soft circular highlight sits top-right.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.label,
    required this.amount,
    this.pills = const [],
    this.icon,
  });

  /// Small caption above the amount, e.g. `💰 Money left over`.
  final String label;

  /// The large headline value, already formatted (currency + grouping).
  final String amount;

  /// Zero or more short pill strings shown beneath the amount.
  final List<String> pills;

  /// Optional leading icon rendered before [label].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // primary → a deeper green, matching the mockup's linear-gradient.
    final gradientEnd = Color.lerp(colorScheme.primary, Colors.black, 0.28)!;
    final onHero = colorScheme.onPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, gradientEnd],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: onHero.withValues(alpha: 0.92)),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: onHero.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: onHero,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final pill in pills)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: onHero.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            pill,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: onHero,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Soft top-right circular highlight (mockup `.hero::after`).
          Positioned(
            right: -40,
            top: -40,
            child: IgnorePointer(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onHero.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
