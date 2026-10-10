import 'package:intl/intl.dart';

/// A single selectable currency, used by the settings picker and formatters.
class CurrencyOption {
  final String code; // e.g. 'ZAR'
  final String symbol; // e.g. 'R'
  final String name; // e.g. 'South African Rand'

  const CurrencyOption(this.code, this.symbol, this.name);
}

/// Curated, fixed list of supported currencies plus lookup helpers.
///
/// ZAR is first and is the app default. The list intentionally only carries a
/// display symbol — changing currency relabels the symbol and does NOT perform
/// any FX conversion of stored amounts.
class AppCurrencies {
  const AppCurrencies._();

  /// Curated list of supported currencies. ZAR MUST remain first (default).
  static const List<CurrencyOption> all = [
    CurrencyOption('ZAR', 'R', 'South African Rand'),
    CurrencyOption('USD', '\$', 'US Dollar'),
    CurrencyOption('EUR', '€', 'Euro'),
    CurrencyOption('GBP', '£', 'British Pound'),
    CurrencyOption('AUD', 'A\$', 'Australian Dollar'),
    CurrencyOption('CAD', 'C\$', 'Canadian Dollar'),
    CurrencyOption('JPY', '¥', 'Japanese Yen'),
    CurrencyOption('INR', '₹', 'Indian Rupee'),
  ];

  /// Returns the symbol for [code], or [code] itself when unknown.
  static String symbolFor(String code) {
    final option = byCode(code);
    return option?.symbol ?? code;
  }

  /// Returns the matching [CurrencyOption], or null when [code] is unknown.
  static CurrencyOption? byCode(String code) {
    for (final option in all) {
      if (option.code == code) return option;
    }
    return null;
  }
}

/// Pure formatting helper. Has NO dependency on settings state — callers obtain
/// the symbol (e.g. from `SettingsController.currencySymbol`) and pass it in.
class CurrencyFormatter {
  const CurrencyFormatter._();

  static final NumberFormat _grouped = NumberFormat('#,##0.00');
  static final NumberFormat _groupedWhole = NumberFormat('#,##0');

  /// Formats a non-signed amount with grouping + 2 decimals, prefixed by
  /// [symbol]. A negative amount keeps a leading `-` before the symbol; a
  /// positive amount is rendered without a sign.
  ///
  /// `format('R', 1234.5)`  => `'R1,234.50'`
  /// `format('R', -1234.5)` => `'-R1,234.50'`
  static String format(String symbol, double amount) {
    final sign = amount < 0 ? '-' : '';
    return '$sign$symbol${_grouped.format(amount.abs())}';
  }

  /// Signed variant for income(+)/expense(-) display. The magnitude of
  /// [amount] is formatted and prefixed with the sign + symbol.
  ///
  /// `formatSigned('R', 1234.5, isIncome: true)`  => `'+R1,234.50'`
  /// `formatSigned('R', 1234.5, isIncome: false)` => `'-R1,234.50'`
  static String formatSigned(
    String symbol,
    double amount, {
    required bool isIncome,
  }) {
    final sign = isIncome ? '+' : '-';
    return '$sign$symbol${_grouped.format(amount.abs())}';
  }

  /// Compact form for chart axis labels.
  ///
  /// `formatCompact('R', 12000)` => `'R12k'`
  /// `formatCompact('R', 1500000)` => `'R1.5M'`
  static String formatCompact(String symbol, double amount) {
    final value = amount.abs();
    final sign = amount < 0 ? '-' : '';

    if (value >= 1000000000) {
      return '$sign$symbol${_trim(value / 1000000000)}B';
    }
    if (value >= 1000000) {
      return '$sign$symbol${_trim(value / 1000000)}M';
    }
    if (value >= 1000) {
      return '$sign$symbol${_trim(value / 1000)}k';
    }
    return '$sign$symbol${_groupedWhole.format(value)}';
  }

  /// Formats a scaled compact value, dropping a trailing `.0`.
  static String _trim(double value) {
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(1);
  }
}
