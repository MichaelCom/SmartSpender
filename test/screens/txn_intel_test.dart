import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_spender/providers/budget_provider.dart';
import 'package:smart_spender/providers/category_provider.dart';
import 'package:smart_spender/providers/settings_provider.dart';
import 'package:smart_spender/providers/transaction_provider.dart';
import 'package:smart_spender/repositories/repositories.dart';
import 'package:smart_spender/screens/transactions/add_transaction_screen.dart';
import 'package:smart_spender/screens/transactions/transaction_list_screen.dart';

import '../helpers/test_db.dart';

void main() {
  late TestDb testDb;

  setUp(() {
    testDb = TestDb.create();
  });

  tearDown(() async {
    await testDb.dispose();
  });

  Widget buildApp(Widget home) {
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
      child: MaterialApp(home: home),
    );
  }

  testWidgets('add transaction screen builds', (tester) async {
    await tester.pumpWidget(buildApp(const AddTransactionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.text('Description (Optional)'), findsOneWidget);
  });

  testWidgets(
    'suggestion chip appears from history and is applied on tap',
    (tester) async {
      final repos = testDb.repositories;

      // Seed an expense category and tagging history so the engine suggests it.
      final catId = await repos.categories.insert(
        makeCategory(name: 'Food & Dining', type: 'expense'),
      );
      for (var i = 0; i < 3; i++) {
        await repos.transactions.insert(
          makeTransaction(
            amount: 50 + i.toDouble(),
            description: 'Woolworths lunch',
            categoryId: catId,
            type: 'expense',
          ),
        );
      }

      await tester.pumpWidget(buildApp(const AddTransactionScreen()));
      // Prime providers.
      final ctx = tester.element(find.byType(AddTransactionScreen));
      await ctx.read<CategoryProvider>().loadCategories();
      await ctx.read<TransactionProvider>().loadTransactions();
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (Optional)'),
        'Woolworths',
      );
      // Wait out the 400ms debounce.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Suggested: Food & Dining'), findsOneWidget);

      await tester.tap(find.text('Suggested: Food & Dining'));
      await tester.pumpAndSettle();

      // Chip disappears once a category is chosen.
      expect(find.text('Suggested: Food & Dining'), findsNothing);
    },
  );

  testWidgets('transaction list builds and flags an anomaly', (tester) async {
    final repos = testDb.repositories;

    final catId = await repos.categories.insert(
      makeCategory(name: 'Food & Dining', type: 'expense'),
    );
    // Enough typical history (>= minSamples) for a stable baseline.
    for (var i = 0; i < 8; i++) {
      await repos.transactions.insert(
        makeTransaction(
          amount: 50 + (i % 3).toDouble(),
          description: 'Normal buy $i',
          categoryId: catId,
          type: 'expense',
        ),
      );
    }
    // An obvious outlier that should be flagged.
    await repos.transactions.insert(
      makeTransaction(
        amount: 5000,
        description: 'Huge spend',
        categoryId: catId,
        type: 'expense',
      ),
    );

    await tester.pumpWidget(buildApp(const TransactionListScreen()));
    final ctx = tester.element(find.byType(TransactionListScreen));
    await ctx.read<CategoryProvider>().loadCategories();
    await ctx.read<TransactionProvider>().loadTransactions();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Outlier was inserted last and may sit below the fold in the lazy list;
    // drag the list up to bring it into view.
    await tester.scrollUntilVisible(
      find.text('Huge spend'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Huge spend'), findsOneWidget);

    expect(find.text('Unusually large'), findsWidgets);
  });
}
