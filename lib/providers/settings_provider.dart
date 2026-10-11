import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/currency.dart';

/// App-wide user settings persisted via [SharedPreferences].
///
/// Holds the current [ThemeMode] and the display [currencyCode]. Loaded once
/// at startup via [SettingsController.load] (before `runApp`) and provided at
/// the top of the widget tree so any screen can read/update it.
class SettingsController extends ChangeNotifier {
  /// Construct with already-loaded values; see [SettingsController.load].
  SettingsController({
    required ThemeMode themeMode,
    required String currencyCode,
    int budgetAlertThreshold = defaultBudgetAlertThreshold,
  })  : _themeMode = themeMode,
        _currencyCode = currencyCode,
        _budgetAlertThreshold = budgetAlertThreshold;

  /// SharedPreferences key for the persisted theme mode.
  static const String themeModeKey = 'settings.themeMode';

  /// SharedPreferences key for the persisted currency code.
  static const String currencyCodeKey = 'settings.currencyCode';

  /// SharedPreferences key for the persisted budget-alert threshold (percent).
  static const String budgetAlertThresholdKey =
      'settings.budgetAlertThreshold';

  /// Default theme mode used when nothing is persisted.
  static const ThemeMode defaultThemeMode = ThemeMode.system;

  /// Default currency code used when nothing is persisted.
  static const String defaultCurrencyCode = 'ZAR';

  /// Default budget-alert threshold (percent) used when nothing is persisted.
  static const int defaultBudgetAlertThreshold = 80;

  ThemeMode _themeMode;
  String _currencyCode;
  int _budgetAlertThreshold;

  // --- Theme ---

  /// Current theme mode: `system`, `light`, or `dark`.
  ThemeMode get themeMode => _themeMode;

  /// Updates the theme mode, persists it, and notifies listeners.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, _themeModeToString(mode));
  }

  // --- Currency ---

  /// ISO-like code, e.g. `'ZAR'`, `'USD'`. Default: `'ZAR'`.
  String get currencyCode => _currencyCode;

  /// Updates the currency code, persists it, and notifies listeners.
  Future<void> setCurrencyCode(String code) async {
    if (_currencyCode == code) return;
    _currencyCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(currencyCodeKey, code);
  }

  /// The symbol for the current [currencyCode] (e.g. `'R'`, `'\$'`, `'€'`).
  ///
  /// Delegates to [AppCurrencies.symbolFor].
  String get currencySymbol => AppCurrencies.symbolFor(_currencyCode);

  // --- Budget alerts ---

  /// The "nearing" boundary percentage (1..100) at which a budget is flagged.
  /// Default: 80.
  int get budgetAlertThreshold => _budgetAlertThreshold;

  /// Updates the budget-alert threshold (clamped to 1..100), persists it, and
  /// notifies listeners. No-ops when the clamped value is unchanged.
  Future<void> setBudgetAlertThreshold(int percent) async {
    final clamped = percent.clamp(1, 100);
    if (_budgetAlertThreshold == clamped) return;
    _budgetAlertThreshold = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(budgetAlertThresholdKey, clamped);
  }

  /// Async factory that reads [SharedPreferences] and returns a ready instance.
  ///
  /// Falls back to defaults ([ThemeMode.system], `'ZAR'`) if unset or invalid.
  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeMode =
        _themeModeFromString(prefs.getString(themeModeKey)) ?? defaultThemeMode;
    final currencyCode = prefs.getString(currencyCodeKey) ?? defaultCurrencyCode;
    final budgetAlertThreshold =
        (prefs.getInt(budgetAlertThresholdKey) ?? defaultBudgetAlertThreshold)
            .clamp(1, 100);
    return SettingsController(
      themeMode: themeMode,
      currencyCode: currencyCode,
      budgetAlertThreshold: budgetAlertThreshold,
    );
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static ThemeMode? _themeModeFromString(String? value) {
    switch (value) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }
}
