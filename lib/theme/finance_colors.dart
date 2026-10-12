import 'package:flutter/material.dart';

/// Semantic finance colours that stay constant across light/dark.
///
/// These express *intent* (money in / out / warning / info) rather than the
/// Material 3 scheme roles, so they are carried as a [ThemeExtension] instead
/// of being derived from the [ColorScheme]. Resolve them with:
///
/// ```dart
/// final finance = Theme.of(context).financeColors;
/// Text('...', style: TextStyle(color: finance.income));
/// ```
///
/// The values mirror the web redesign and the mobile mockup tokens
/// (`--m3-income`, `--m3-expense`, `--m3-warning`, `--m3-info`).
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.info,
  });

  /// Money coming in (positive). Mockup `--m3-income`.
  final Color income;

  /// Money going out (negative). Mockup `--m3-expense`.
  final Color expense;

  /// A budget nearing its limit, or other caution state. Mockup `--m3-warning`.
  final Color warning;

  /// Informational accent (tips, suggestions). Mockup `--m3-info`.
  final Color info;

  /// The single shared instance — identical in light and dark, matching the
  /// mockups which keep finance colours constant across themes.
  static const FinanceColors standard = FinanceColors(
    income: Color(0xFF2E7D32),
    expense: Color(0xFFC62828),
    warning: Color(0xFFF9A825),
    info: Color(0xFF1565C0),
  );

  @override
  FinanceColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? info,
  }) {
    return FinanceColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t) ?? income,
      expense: Color.lerp(expense, other.expense, t) ?? expense,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}

/// Convenience accessor so screens can read finance colours without the verbose
/// `extension<FinanceColors>()!` dance.
extension FinanceColorsX on ThemeData {
  /// The app's semantic finance colours. Always present (registered in
  /// `AppTheme`), so the non-null assertion is safe.
  FinanceColors get financeColors => extension<FinanceColors>()!;
}
