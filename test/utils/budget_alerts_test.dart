import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/utils/budget_alerts.dart';

void main() {
  group('BudgetAlerts.evaluate', () {
    test('ok when spending is below the threshold', () {
      final status = BudgetAlerts.evaluate(
        spent: 50,
        limit: 100,
        thresholdPercent: 80,
      );

      expect(status.level, BudgetAlertLevel.ok);
      expect(status.isOk, isTrue);
      expect(status.progress, 0.5);
      expect(status.spent, 50);
      expect(status.limit, 100);
      expect(status.overBy, 0.0);
    });

    test('nearing when progress reaches the threshold exactly', () {
      final status = BudgetAlerts.evaluate(
        spent: 80,
        limit: 100,
        thresholdPercent: 80,
      );

      expect(status.level, BudgetAlertLevel.nearing);
      expect(status.isNearing, isTrue);
      expect(status.progress, 0.8);
      expect(status.overBy, 0.0);
    });

    test('nearing when progress is above the threshold but at/under limit', () {
      final status = BudgetAlerts.evaluate(
        spent: 99.99,
        limit: 100,
        thresholdPercent: 80,
      );

      expect(status.level, BudgetAlertLevel.nearing);
    });

    test('nearing at exactly the limit (not exceeded)', () {
      final status = BudgetAlerts.evaluate(
        spent: 100,
        limit: 100,
        thresholdPercent: 80,
      );

      expect(status.level, BudgetAlertLevel.nearing);
      expect(status.isExceeded, isFalse);
    });

    test('exceeded when spent is strictly over the limit', () {
      final status = BudgetAlerts.evaluate(
        spent: 120,
        limit: 100,
        thresholdPercent: 80,
      );

      expect(status.level, BudgetAlertLevel.exceeded);
      expect(status.isExceeded, isTrue);
      expect(status.progress, 1.2);
      expect(status.overBy, closeTo(20.0, 1e-9));
    });

    test('progress is unclamped and can exceed 1.0', () {
      final status = BudgetAlerts.evaluate(
        spent: 250,
        limit: 100,
        thresholdPercent: 80,
      );

      expect(status.progress, 2.5);
      expect(status.level, BudgetAlertLevel.exceeded);
    });

    test('zero or negative limit yields zero progress and never nearing', () {
      final zero = BudgetAlerts.evaluate(
        spent: 0,
        limit: 0,
        thresholdPercent: 80,
      );
      expect(zero.progress, 0.0);
      expect(zero.level, BudgetAlertLevel.ok);

      // Any positive spend against a non-positive limit is "exceeded"
      // (spent > limit) rather than nearing.
      final overZero = BudgetAlerts.evaluate(
        spent: 10,
        limit: 0,
        thresholdPercent: 80,
      );
      expect(overZero.progress, 0.0);
      expect(overZero.level, BudgetAlertLevel.exceeded);
    });

    test('threshold of 100 only flags nearing at full spend', () {
      final almost = BudgetAlerts.evaluate(
        spent: 99,
        limit: 100,
        thresholdPercent: 100,
      );
      expect(almost.level, BudgetAlertLevel.ok);

      final full = BudgetAlerts.evaluate(
        spent: 100,
        limit: 100,
        thresholdPercent: 100,
      );
      expect(full.level, BudgetAlertLevel.nearing);
    });

    test('threshold of 1 flags nearing almost immediately', () {
      final status = BudgetAlerts.evaluate(
        spent: 1,
        limit: 100,
        thresholdPercent: 1,
      );
      expect(status.level, BudgetAlertLevel.nearing);
    });

    test('zero spend is ok', () {
      final status = BudgetAlerts.evaluate(
        spent: 0,
        limit: 100,
        thresholdPercent: 80,
      );
      expect(status.level, BudgetAlertLevel.ok);
      expect(status.progress, 0.0);
    });
  });
}
