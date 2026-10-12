import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../utils/currency.dart';
import '../../widgets/redesign/redesign.dart';
import 'data_management_section.dart';

/// Settings screen: Appearance (theme mode) and Currency (display symbol).
///
/// Reads and updates the shared [SettingsController]. Currency selection only
/// changes the displayed symbol; stored amounts are never converted.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('Appearance'),
          _FlatCard(
            child: RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (mode) => _setThemeMode(settings, mode),
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('System'),
                    subtitle: Text('Follow the device theme'),
                    value: ThemeMode.system,
                  ),
                  Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Light'),
                    value: ThemeMode.light,
                  ),
                  Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Dark'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const SectionHeader('Currency'),
          _FlatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Display currency'),
                  subtitle: Text(_currencyLabel(settings.currencyCode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCurrencyPicker(context, settings),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                  child: Text(
                    'Changes the display symbol only; amounts are not '
                    'converted.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const SectionHeader('Budget alerts'),
          _FlatCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Alert threshold'),
              subtitle: const Text(
                'Warn when a budget reaches this percentage.',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Decrease',
                    onPressed: settings.budgetAlertThreshold > 1
                        ? () => settings.setBudgetAlertThreshold(
                              settings.budgetAlertThreshold - 5,
                            )
                        : null,
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${settings.budgetAlertThreshold}%',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Increase',
                    onPressed: settings.budgetAlertThreshold < 100
                        ? () => settings.setBudgetAlertThreshold(
                              settings.budgetAlertThreshold + 5,
                            )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const SectionHeader('Data'),
          const _FlatCard(child: DataManagementSection()),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'SmartSpender · v1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

/// A flat, outlined card matching the mockup `.m-card.flat` used for the
/// Settings groups.
class _FlatCard extends StatelessWidget {
  const _FlatCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
