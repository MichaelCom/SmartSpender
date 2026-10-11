import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/services/insights/insights_engine.dart';

import '../../helpers/test_db.dart';

void main() {
  late TestDb env;
  // Fixed "today" mid-month for deterministic run-rate.
  final now = DateTime(2024, 6, 15);

  setUp(() {
    env = TestDb.create();
  });

  tearDown(() async {
    await env.dispose();
  });

  Future<int> seedCategory(String name, {String type = 'expense'}) {
    return env.repositories.categories
        .insert(makeCategory(name: name, type: type));
  }

  group('InsightsEngine.buildInsights', () {
    test('empty data produces no insights', () async {
      final engine = InsightsEngine(env.repositories);
      final insights = await engine.buildInsights(now: now);
      expect(insights, isEmpty);
    });

    test('savings-rate insight when income exceeds expenses', () async {
      final salary = await seedCategory('Salary', type: 'income');
      final food = await seedCategory('Food');
      await env.repositories.transactions.insert(makeTransaction(
          type: 'income', amount: 1000, categoryId: salary, date: DateTime(2024, 6, 5)));
      await env.repositories.transactions.insert(makeTransaction(
          type: 'expense', amount: 200, categoryId: food, date: DateTime(2024, 6, 6)));

      final engine = InsightsEngine(env.repositories);
      final insights = await engine.buildInsights(now: now);
      expect(insights.any((i) => i.title == 'Savings rate'), isTrue);
    });

    test('warns when spending exceeds income', () async {
      final salary = await seedCategory('Salary', type: 'income');
      final food = await seedCategory('Food');
      await env.repositories.transactions.insert(makeTransaction(
          type: 'income', amount: 200, categoryId: salary, date: DateTime(2024, 6, 5)));
      await env.repositories.transactions.insert(makeTransaction(
          type: 'expense', amount: 500, categoryId: food, date: DateTime(2024, 6, 6)));

      final engine = InsightsEngine(env.repositories);
      final insights = await engine.buildInsights(now: now);
      expect(insights.any((i) => i.title == 'Spending exceeds income'), isTrue);
    });

    test('biggest-category insight names the top expense category', () async {
      final food = await seedCategory('Food');
      final transport = await seedCategory('Transport');
      await env.repositories.transactions.insert(makeTransaction(
          type: 'expense', amount: 800, categoryId: food, date: DateTime(2024, 6, 5)));
      await env.repositories.transactions.insert(makeTransaction(
          type: 'expense', amount: 100, categoryId: transport, date: DateTime(2024, 6, 6)));

      final engine = InsightsEngine(env.repositories);
      final insights = await engine.buildInsights(now: now);
      final biggest = insights.firstWhere((i) => i.title == 'Biggest expense category');
      expect(biggest.detail, contains('Food'));
    });

    test('top-mover insight compares against last month', () async {
      final food = await seedCategory('Food');
      // Last month R100, this month R400 -> big rise.
      await env.repositories.transactions.insert(makeTransaction(
          type: 'expense', amount: 100, categoryId: food, date: DateTime(2024, 5, 10)));
      await env.repositories.transactions.insert(makeTransaction(
          type: 'expense', amount: 400, categoryId: food, date: DateTime(2024, 6, 10)));

      final engine = InsightsEngine(env.repositories);
      final insights = await engine.buildInsights(now: now);
      final mover = insights.firstWhere(
          (i) => i.title == 'Biggest change vs last month',
          orElse: () => throw StateError('no mover insight'));
      expect(mover.detail, contains('Food'));
      expect(mover.detail.toLowerCase(), contains('rose'));
    });

    test('topInsight returns the highest-priority insight', () async {
      final salary = await seedCategory('Salary', type: 'income');
      final food = await seedCategory('Food');
      // Overspend scenario (priority 80) should outrank savings info.
      await env.repositories.transactions.insert(makeTransaction(
          type: 'income', amount: 100, categoryId: salary, date: DateTime(2024, 6, 5)));
      await env.repositories.transactions.insert(makeTransaction(
          type: 'expense', amount: 900, categoryId: food, date: DateTime(2024, 6, 6)));

      final engine = InsightsEngine(env.repositories);
      final top = await engine.topInsight(now: now);
      expect(top, isNotNull);
      expect(top!.title, 'Spending exceeds income');
    });

    test('currency symbol is used in amount strings', () async {
      final salary = await seedCategory('Salary', type: 'income');
      final food = await seedCategory('Food');
      await env.repositories.transactions.insert(makeTransaction(
          type: 'income', amount: 100, categoryId: salary, date: DateTime(2024, 6, 5)));
      await env.repositories.transactions.insert(makeTransaction(
          type: 'expense', amount: 500, categoryId: food, date: DateTime(2024, 6, 6)));

      final engine = InsightsEngine(env.repositories);
      final insights =
          await engine.buildInsights(now: now, currencySymbol: '\$');
      final overspend =
          insights.firstWhere((i) => i.title == 'Spending exceeds income');
      expect(overspend.detail, contains('\$'));
    });
  });
}
