import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/models/transaction.dart';
import 'package:smart_spender/services/insights/anomaly_engine.dart';

Transaction _tx(double amount, {int categoryId = 1, String type = 'expense'}) =>
    Transaction(
      amount: amount,
      description: 'tx',
      categoryId: categoryId,
      date: DateTime(2024, 6, 1),
      type: type,
      createdAt: DateTime(2024, 6, 1),
    );

void main() {
  group('AnomalyEngine', () {
    test('flags an expense well above the category mean', () {
      // Baseline ~100 with low variance, then a 1000 outlier.
      final history = [
        for (final a in <double>[100, 110, 90, 105, 95, 100, 102]) _tx(a),
      ];
      final outlier = _tx(1000);
      final result = AnomalyEngine.detect(
        transactions: [outlier],
        history: [...history, outlier],
      );
      expect(result, hasLength(1));
      expect(result.first.transaction.amount, 1000);
      expect(result.first.zScore, greaterThan(2.0));
      expect(result.first.timesTypical, greaterThan(5));
    });

    test('does not flag when below the minimum sample count', () {
      final history = [for (final a in <double>[100, 110, 90]) _tx(a)]; // <6
      final outlier = _tx(1000);
      final result = AnomalyEngine.detect(
        transactions: [outlier],
        history: [...history, outlier],
      );
      expect(result, isEmpty);
    });

    test('does not flag below-average spend', () {
      final history = [
        for (final a in <double>[100, 110, 90, 105, 95, 100, 102]) _tx(a),
      ];
      final low = _tx(5);
      final result = AnomalyEngine.detect(
        transactions: [low],
        history: [...history, low],
      );
      expect(result, isEmpty);
    });

    test('does not flag a value within normal variance', () {
      final history = [
        for (final a in <double>[100, 110, 90, 105, 95, 100, 102]) _tx(a),
      ];
      final normal = _tx(107); // within ~2 sd of a ~100 mean (sd ~6.7)
      final result = AnomalyEngine.detect(
        transactions: [normal],
        history: [...history, normal],
      );
      expect(result, isEmpty);
    });

    test('judges each category independently', () {
      final catA = [for (final a in <double>[100, 110, 90, 105, 95, 100]) _tx(a, categoryId: 1)];
      final catB = [for (final a in <double>[1000, 1100, 900, 1050, 950, 1000]) _tx(a, categoryId: 2)];
      // 500 is huge for A but small for B.
      final txA = _tx(500, categoryId: 1);
      final txB = _tx(500, categoryId: 2);
      final result = AnomalyEngine.detect(
        transactions: [txA, txB],
        history: [...catA, ...catB, txA, txB],
      );
      expect(result.map((a) => a.transaction.categoryId), contains(1));
      expect(result.map((a) => a.transaction.categoryId), isNot(contains(2)));
    });

    test('ignores income transactions', () {
      final history = [
        for (final a in <double>[100, 110, 90, 105, 95, 100, 102]) _tx(a, type: 'income'),
      ];
      final outlier = _tx(1000, type: 'income');
      final result = AnomalyEngine.detect(
        transactions: [outlier],
        history: [...history, outlier],
      );
      expect(result, isEmpty);
    });

    test('sorts most extreme first', () {
      final history = [for (final a in <double>[100, 110, 90, 105, 95, 100, 102]) _tx(a)];
      final big = _tx(1000);
      final bigger = _tx(2000);
      final result = AnomalyEngine.detect(
        transactions: [big, bigger],
        history: [...history, big, bigger],
      );
      expect(result.first.transaction.amount, 2000);
    });
  });
}
