import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/models/category.dart';
import 'package:smart_spender/models/transaction.dart';
import 'package:smart_spender/services/insights/categorization_engine.dart';

Category _cat(int id, String name, {String type = 'expense'}) =>
    Category(id: id, name: name, type: type, createdAt: DateTime(2024));

Transaction _tx(String desc, int? categoryId, {String type = 'expense'}) =>
    Transaction(
      amount: 10,
      description: desc,
      categoryId: categoryId,
      date: DateTime(2024, 6, 1),
      type: type,
      createdAt: DateTime(2024, 6, 1),
    );

void main() {
  final categories = [
    _cat(1, 'Transportation'),
    _cat(2, 'Food & Dining'),
    _cat(3, 'Entertainment'),
    _cat(10, 'Salary', type: 'income'),
  ];

  group('seed rules', () {
    test('maps a known keyword to the matching category', () {
      final s = CategorizationEngine.suggest(
        description: 'Uber trip home',
        categories: categories,
        history: const [],
      );
      expect(s, isNotNull);
      expect(s!.categoryId, 1);
      expect(s.fromHistory, isFalse);
    });

    test('longer keyword wins (uber eats -> Food, not Transport)', () {
      final s = CategorizationEngine.suggest(
        description: 'Uber Eats dinner',
        categories: categories,
        history: const [],
      );
      expect(s!.categoryId, 2);
    });

    test('returns null when no keyword and no history match', () {
      final s = CategorizationEngine.suggest(
        description: 'xyzzy nothing here',
        categories: categories,
        history: const [],
      );
      expect(s, isNull);
    });

    test('skips a seed rule when no matching category exists', () {
      final s = CategorizationEngine.suggest(
        description: 'netflix subscription',
        categories: [_cat(1, 'Transportation')], // no Entertainment
        history: const [],
      );
      expect(s, isNull);
    });

    test('empty description yields null', () {
      final s = CategorizationEngine.suggest(
        description: '   ',
        categories: categories,
        history: const [],
      );
      expect(s, isNull);
    });
  });

  group('history learning', () {
    test('history overrides seed rules once confident', () {
      // "uber" would seed to Transportation(1), but the user keeps tagging
      // things that mention "uber" as Entertainment(3).
      final history = [
        _tx('uber ride', 3),
        _tx('uber ride', 3),
      ];
      final s = CategorizationEngine.suggest(
        description: 'uber ride again',
        categories: categories,
        history: history,
      );
      expect(s!.categoryId, 3);
      expect(s.fromHistory, isTrue);
    });

    test('below the min-match threshold falls back to seed rule', () {
      final history = [_tx('uber ride', 3)]; // only 1 precedent (<2)
      final s = CategorizationEngine.suggest(
        description: 'uber ride',
        categories: categories,
        history: history,
      );
      // Falls back to the seed rule -> Transportation.
      expect(s!.categoryId, 1);
      expect(s.fromHistory, isFalse);
    });

    test('type filter restricts suggestions to that type', () {
      final s = CategorizationEngine.suggest(
        description: 'salary payment',
        categories: categories,
        history: const [],
        type: 'income',
      );
      expect(s!.categoryId, 10);

      // Same description but asking for expense categories -> no income match.
      final s2 = CategorizationEngine.suggest(
        description: 'salary payment',
        categories: categories,
        history: const [],
        type: 'expense',
      );
      expect(s2, isNull);
    });

    test('ignores history pointing at a deleted/unknown category', () {
      final history = [
        _tx('coffee shop', 999), // category 999 not in list
        _tx('coffee shop', 999),
      ];
      final s = CategorizationEngine.suggest(
        description: 'coffee shop morning',
        categories: categories,
        history: history,
      );
      // History is unusable; falls back to seed ('coffee' -> Food & Dining).
      expect(s!.categoryId, 2);
      expect(s.fromHistory, isFalse);
    });
  });
}
