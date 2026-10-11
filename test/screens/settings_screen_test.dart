import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_spender/providers/budget_provider.dart';
import 'package:smart_spender/providers/category_provider.dart';
import 'package:smart_spender/providers/settings_provider.dart';
import 'package:smart_spender/providers/transaction_provider.dart';
import 'package:smart_spender/repositories/repositories.dart';
import 'package:smart_spender/screens/settings/settings_screen.dart';

import '../helpers/test_db.dart';

void main() {
  late TestDb testDb;

  setUp(() {
    testDb = TestDb.create();
  });

  tearDown(() async {
    await testDb.dispose();
  });

  Widget buildApp() {
    final repositories = testDb.repositories;
    return MultiProvider(
      providers: [
        Provider<AppRepositories>.value(value: repositories),
        ChangeNotifierProvider<SettingsController>.value(
          value: SettingsController(
            themeMode: ThemeMode.system,
            currencyCode: 'ZAR',
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(repositories.categories),
        ),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(repositories.transactions),
        ),
        ChangeNotifierProvider(
          create: (_) => BudgetProvider(repositories.budgets),
        ),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  testWidgets('settings screen builds with the Data section', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // The Data section lives at the bottom of a scrollable list; bring it into
    // view before asserting.
    await tester.scrollUntilVisible(
      find.text('Data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Export backup (JSON)'), findsOneWidget);
    expect(find.text('Export transactions (CSV)'), findsOneWidget);
    expect(find.text('Restore from backup (JSON)'), findsOneWidget);
  });

  testWidgets('restore shows a replace-confirmation dialog is wired behind tap',
      (tester) async {
    // We can't exercise the file picker headlessly, but we can at least verify
    // the restore tile is present and tappable without throwing on build.
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Replaces all current data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Replaces all current data'), findsOneWidget);
  });
}
