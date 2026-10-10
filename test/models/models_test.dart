import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/models/budget.dart';
import 'package:smart_spender/models/category.dart';
import 'package:smart_spender/models/transaction.dart';

void main() {
  group('Transaction', () {
    test('isIncome / isExpense reflect type', () {
      final income = Transaction(
        amount: 50,
        categoryId: 1,
        date: DateTime(2024, 1, 1),
        type: 'income',
        createdAt: DateTime(2024, 1, 1),
      );
      final expense = Transaction(
        amount: 50,
        categoryId: 1,
        date: DateTime(2024, 1, 1),
        type: 'expense',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(income.isIncome, isTrue);
      expect(income.isExpense, isFalse);
      expect(expense.isExpense, isTrue);
      expect(expense.isIncome, isFalse);
    });

    test('formattedAmount keeps two decimals', () {
      final tx = Transaction(
        amount: 12.5,
        categoryId: 1,
        date: DateTime(2024, 1, 1),
        type: 'expense',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(tx.formattedAmount, '12.50');
    });

    test('formattedAmount keeps two decimals for whole and fractional', () {
      final income = Transaction(
        amount: 100,
        categoryId: 1,
        date: DateTime(2024, 1, 1),
        type: 'income',
        createdAt: DateTime(2024, 1, 1),
      );
      final expense = Transaction(
        amount: 100,
        categoryId: 1,
        date: DateTime(2024, 1, 1),
        type: 'expense',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(income.formattedAmount, '100.00');
      expect(expense.formattedAmount, '100.00');
    });

    test('copyWith overrides only provided fields', () {
      final tx = Transaction(
        amount: 10,
        description: 'Coffee',
        categoryId: 1,
        date: DateTime(2024, 1, 1),
        type: 'expense',
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = tx.copyWith(amount: 20, description: 'Lunch');

      expect(updated.amount, 20);
      expect(updated.description, 'Lunch');
      expect(updated.categoryKey, 1);
      expect(updated.type, 'expense');
    });

    test('categoryId mirrors categoryKey', () {
      final tx = Transaction(
        amount: 10,
        categoryId: 7,
        date: DateTime(2024, 1, 1),
        type: 'expense',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(tx.categoryId, 7);
    });
  });

  group('Budget progress helpers', () {
    final budget = Budget(
      categoryId: 1,
      amount: 1000,
      period: 'monthly',
      startDate: DateTime(2024, 6, 1),
      endDate: DateTime(2024, 6, 30),
      createdAt: DateTime(2024, 6, 1),
    );

    test('calculateProgress clamps between 0 and 1', () {
      expect(budget.calculateProgress(500), 0.5);
      expect(budget.calculateProgress(0), 0.0);
      expect(budget.calculateProgress(2000), 1.0);
    });

    test('calculateProgress returns 0 when amount is non-positive', () {
      final zero = Budget(
        categoryId: 1,
        amount: 0,
        period: 'monthly',
        startDate: DateTime(2024, 6, 1),
        endDate: DateTime(2024, 6, 30),
        createdAt: DateTime(2024, 6, 1),
      );
      expect(zero.calculateProgress(100), 0.0);
    });

    test('isExceeded is strict greater-than', () {
      expect(budget.isExceeded(1000), isFalse);
      expect(budget.isExceeded(1000.01), isTrue);
    });

    test('getRemainingAmount floors at zero', () {
      expect(budget.getRemainingAmount(300), 700);
      expect(budget.getRemainingAmount(1500), 0);
    });

    test('period helpers reflect the period string', () {
      expect(budget.isMonthly, isTrue);
      expect(budget.isWeekly, isFalse);
      expect(budget.isYearly, isFalse);
    });

    test('formattedAmount formats amount', () {
      expect(budget.formattedAmount, '1000.00');
    });

    test('isActive is true only within the window', () {
      final now = DateTime.now();
      final active = Budget(
        categoryId: 1,
        amount: 100,
        period: 'monthly',
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 5)),
        createdAt: now,
      );
      final past = Budget(
        categoryId: 1,
        amount: 100,
        period: 'monthly',
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 10)),
        createdAt: now,
      );

      expect(active.isActive, isTrue);
      expect(past.isActive, isFalse);
    });
  });

  group('Category', () {
    test('isIncome / isExpense reflect type', () {
      final income = Category(
        name: 'Salary',
        type: 'income',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(income.isIncome, isTrue);
      expect(income.isExpense, isFalse);
    });

    test('copyWith overrides only provided fields', () {
      final cat = Category(
        name: 'Food',
        type: 'expense',
        color: '#FF0000',
        icon: 'restaurant',
        createdAt: DateTime(2024, 1, 1),
      );
      final updated = cat.copyWith(name: 'Groceries');
      expect(updated.name, 'Groceries');
      expect(updated.type, 'expense');
      expect(updated.color, '#FF0000');
    });
  });
}
