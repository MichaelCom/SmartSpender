# Mobile Redesign — API Contract (Foundation Layer)

This document defines the shared theme layer and reusable widget APIs that
every screen agent MUST consume. Agents must NOT redefine, duplicate, or
modify any of these files.

---

## Theme

### `lib/theme/app_theme.dart`

```dart
class AppTheme {
  static ThemeData light();
  static ThemeData dark();
}
```

Already wired into `main.dart`. Screens resolve colours via
`Theme.of(context).colorScheme` — never hardcode hex.

### `lib/theme/finance_colors.dart`

```dart
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  final Color income;   // #2E7D32
  final Color expense;  // #C62828
  final Color warning;  // #F9A825
  final Color info;     // #1565C0

  static const FinanceColors standard;
}

// Convenience getter:
extension FinanceColorsX on ThemeData {
  FinanceColors get financeColors;
}
```

Usage: `Theme.of(context).financeColors.income`.

---

## Shared widgets — `lib/widgets/redesign/`

Import via: `import '../../widgets/redesign/redesign.dart';`
(or adjust depth as needed).

### CategoryIconChip

Centralised hex→Color and icon-name→IconData mapping. **Screens must delete
their own `_hexToColor` / `_getIconData` copies and use these instead.**

```dart
Color categoryColorFromHex(String? hex, {Color fallback});
IconData categoryIconFromName(String? name);

const List<String> categoryIconChoices;   // the 20 icon names
const List<String> categoryColorChoices;  // the 15 hex swatches

class CategoryIconChip extends StatelessWidget {
  const CategoryIconChip({String? colorHex, String? iconName, double size, double radius, double? iconSize});
}
```

### GradientHero

Dashboard hero card: gradient, big amount, pill row.

```dart
class GradientHero extends StatelessWidget {
  const GradientHero({required String label, required String amount, List<String> pills, IconData? icon});
}
```

### MiniStatTile / MiniStatRow

2-up statistic tiles (income/expense, budgeted/spent, quick actions).

```dart
class MiniStatTile extends StatelessWidget {
  const MiniStatTile({required String label, String? value, IconData? icon, Color? iconColor, Color? valueColor, bool centred, VoidCallback? onTap});
}

class MiniStatRow extends StatelessWidget {
  const MiniStatRow({required List<Widget> tiles});
}
```

### FinanceListRow

Row with leading CategoryIconChip, title, subtitle, trailing amount.

```dart
class FinanceListRow extends StatelessWidget {
  const FinanceListRow({required String title, String? subtitle, Widget? subtitleWidget, String? colorHex, String? iconName, String? amountText, Color? amountColor, Widget? trailing, VoidCallback? onTap});

  static Widget divider(BuildContext context);  // hairline between rows
}
```

### StatusBadge / FinanceProgressBar / BudgetStatus

```dart
enum BudgetStatus { onTrack, nearing, over }

class StatusBadge extends StatelessWidget {
  const StatusBadge({required BudgetStatus status, String? label});
}

class FinanceProgressBar extends StatelessWidget {
  const FinanceProgressBar({required double value, required BudgetStatus status, double height});
}
```

### SectionHeader

Uppercase, muted section label (e.g. "QUICK ACTIONS", "RECENT").

```dart
class SectionHeader extends StatelessWidget {
  const SectionHeader(String label, {EdgeInsetsGeometry? padding});
}
```

### FilterChipScroller

Horizontal choice-chip row (transactions filter, reports tabs, form pickers).

```dart
class FilterChipOption {
  const FilterChipOption({required String value, required String label, String? icon});
}

class FilterChipScroller extends StatelessWidget {
  const FilterChipScroller({required List<FilterChipOption> options, required String selected, required ValueChanged<String> onSelected});
}
```

### IncomeExpenseSegment

Segmented toggle: selected segment tinted income-green or expense-red.

```dart
class IncomeExpenseSegment extends StatelessWidget {
  const IncomeExpenseSegment({required String value, required ValueChanged<String> onChanged});
}
```

### InfoBanner

Tinted callout (budget alert, smart-category suggestion, recurring summary).

```dart
enum InfoBannerTone { info, warning }

class InfoBanner extends StatelessWidget {
  const InfoBanner({required String icon, String? message, Widget? messageWidget, InfoBannerTone tone, Widget? trailing, VoidCallback? onTap});
}
```

---

## Agent rules

1. Only modify your listed screen files — never edit `lib/theme/`, `lib/widgets/redesign/`, `lib/main.dart`, `pubspec.*`, or any `.g.dart`.
2. Delete local `_hexToColor` / `_getIconData` helpers; use `categoryColorFromHex` / `categoryIconFromName` from the foundation.
3. Preserve all existing provider/engine wiring (data loading, mutations, anomaly detection, insights, forecasting, backup). This is a purely presentational redesign.
4. Reference the mockup at `Docs/smartspender-mockups/mobile/<screen>.html` for the exact layout of your screen. Read its HTML body to understand the component structure.
5. Resolve all colours from `Theme.of(context).colorScheme` or `Theme.of(context).financeColors`. No hardcoded hex.
6. The `LogoWidget` stays as-is (logo_widget.dart) — use it in AppBars that show the brand.
7. Dashboard keeps `inversePrimary` AppBar; detail/list routes use a plain surface AppBar.
8. Run `~/fvm/versions/3.41.7/bin/flutter analyze` before reporting done.
9. Bottom navigation: Dashboard agent migrates `BottomNavigationBar` → `NavigationBar` (M3 pill indicator). Other agents: if your screen is a pushed route (Settings, Recurring list, add-* forms), it has no bottom nav.
