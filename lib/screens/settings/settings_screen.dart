import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../utils/currency.dart';

/// Settings screen: Appearance (theme mode) and Currency (display symbol).
///
/// Reads and updates the shared [SettingsController]. Currency selection only
/// changes the displayed symbol; stored amounts are never converted.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _SectionHeader(label: 'Appearance', context: context),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) => _setThemeMode(settings, mode),
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('System'),
                  subtitle: Text('Follow the device theme'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Light'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Dark'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(label: 'Currency', context: context),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Display currency'),
            subtitle: Text(_currencyLabel(settings.currencyCode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencyPicker(context, settings),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              'Changes the display symbol only; amounts are not converted.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _setThemeMode(SettingsController settings, ThemeMode? mode) {
    if (mode != null) {
      settings.setThemeMode(mode);
    }
  }

  String _currencyLabel(String code) {
    final option = AppCurrencies.byCode(code);
    if (option == null) {
      return code;
    }
    return '${option.name} (${option.symbol} · ${option.code})';
  }

  Future<void> _showCurrencyPicker(
    BuildContext context,
    SettingsController settings,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: RadioGroup<String>(
            groupValue: settings.currencyCode,
            onChanged: (code) => Navigator.of(sheetContext).pop(code),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Select currency',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                for (final option in AppCurrencies.all)
                  RadioListTile<String>(
                    title: Text(option.name),
                    subtitle: Text('${option.symbol} · ${option.code}'),
                    value: option.code,
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await settings.setCurrencyCode(selected);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.context});

  final String label;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
