import 'package:flutter/material.dart';

import '../../theme/finance_colors.dart';

/// The visual intent of an [InfoBanner].
enum InfoBannerTone { info, warning }

/// A tinted callout banner: a leading glyph and a rich message.
///
/// Mirrors the tinted `.m-card` callouts in the mockups — the dashboard budget
/// alert, the add-transaction suggestion, the add-budget / add-recurring notes,
/// and the recurring-list summary. Background is a soft wash of the info blue or
/// warning amber.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    this.message,
    this.messageWidget,
    this.tone = InfoBannerTone.info,
    this.trailing,
    this.onTap,
  });

  /// Leading glyph string (mockups use an emoji such as `💡`, `⚠️`, `🔁`).
  final String icon;

  /// Plain message text. Ignored when [messageWidget] is given.
  final String? message;

  /// Rich message override (e.g. with bold spans). Takes precedence over
  /// [message].
  final Widget? messageWidget;

  /// Colour wash to use.
  final InfoBannerTone tone;

  /// Optional trailing widget (e.g. a chevron for tappable banners).
  final Widget? trailing;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final finance = Theme.of(context).financeColors;
    final colorScheme = Theme.of(context).colorScheme;
    final accent =
        tone == InfoBannerTone.warning ? finance.warning : finance.info;

    final Widget body = messageWidget ??
        Text(
          message ?? '',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: colorScheme.onSurface,
          ),
        );

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: body),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: card,
    );
  }
}
