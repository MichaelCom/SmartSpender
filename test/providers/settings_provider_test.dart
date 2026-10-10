import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_spender/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsController.load', () {
    test('falls back to defaults when nothing persisted', () async {
      SharedPreferences.setMockInitialValues({});

      final controller = await SettingsController.load();

      expect(controller.themeMode, ThemeMode.system);
      expect(controller.currencyCode, 'ZAR');
    });

    test('loads persisted theme mode and currency code', () async {
      SharedPreferences.setMockInitialValues({
        'settings.themeMode': 'dark',
        'settings.currencyCode': 'USD',
      });

      final controller = await SettingsController.load();

      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.currencyCode, 'USD');
    });

    test('falls back to default theme mode for invalid persisted value',
        () async {
      SharedPreferences.setMockInitialValues({
        'settings.themeMode': 'nonsense',
      });

      final controller = await SettingsController.load();

      expect(controller.themeMode, ThemeMode.system);
    });

    test('loads light theme mode', () async {
      SharedPreferences.setMockInitialValues({
        'settings.themeMode': 'light',
      });

      final controller = await SettingsController.load();

      expect(controller.themeMode, ThemeMode.light);
    });
  });

  group('setThemeMode', () {
    test('updates value, notifies listeners, and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await SettingsController.load();

      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setThemeMode(ThemeMode.dark);

      expect(controller.themeMode, ThemeMode.dark);
      expect(notified, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.themeMode'), 'dark');
    });

    test('does not notify when value is unchanged', () async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'light'});
      final controller = await SettingsController.load();

      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setThemeMode(ThemeMode.light);

      expect(notified, 0);
    });

    test('persisted theme mode survives a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await SettingsController.load();
      await controller.setThemeMode(ThemeMode.dark);

      final reloaded = await SettingsController.load();
      expect(reloaded.themeMode, ThemeMode.dark);
    });
  });

  group('setCurrencyCode', () {
    test('updates value, notifies listeners, and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await SettingsController.load();

      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setCurrencyCode('EUR');

      expect(controller.currencyCode, 'EUR');
      expect(notified, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.currencyCode'), 'EUR');
    });

    test('does not notify when value is unchanged', () async {
      SharedPreferences.setMockInitialValues({'settings.currencyCode': 'ZAR'});
      final controller = await SettingsController.load();

      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setCurrencyCode('ZAR');

      expect(notified, 0);
    });

    test('persisted currency code survives a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await SettingsController.load();
      await controller.setCurrencyCode('GBP');

      final reloaded = await SettingsController.load();
      expect(reloaded.currencyCode, 'GBP');
    });
  });

  group('currencySymbol', () {
    test('delegates to AppCurrencies.symbolFor for the current code', () async {
      final controller = SettingsController(
        themeMode: ThemeMode.system,
        currencyCode: 'ZAR',
      );

      // Default ZAR symbol per AppCurrencies contract.
      expect(controller.currencySymbol, 'R');
    });
  });
}
