import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/utils/currency.dart';

void main() {
  group('AppCurrencies', () {
    test('includes all required currencies with ZAR first', () {
      expect(AppCurrencies.all.first.code, 'ZAR');

      final codes = AppCurrencies.all.map((c) => c.code).toList();
      for (final required in [
        'ZAR',
        'USD',
        'EUR',
        'GBP',
        'AUD',
        'CAD',
        'JPY',
        'INR',
      ]) {
        expect(codes, contains(required), reason: '$required must be present');
      }
    });

    test('symbols match the expected display symbols', () {
      expect(AppCurrencies.symbolFor('ZAR'), 'R');
      expect(AppCurrencies.symbolFor('USD'), '\$');
      expect(AppCurrencies.symbolFor('EUR'), '€');
      expect(AppCurrencies.symbolFor('GBP'), '£');
      expect(AppCurrencies.symbolFor('AUD'), 'A\$');
      expect(AppCurrencies.symbolFor('CAD'), 'C\$');
      expect(AppCurrencies.symbolFor('JPY'), '¥');
      expect(AppCurrencies.symbolFor('INR'), '₹');
    });

    test('symbolFor returns the code itself when unknown', () {
      expect(AppCurrencies.symbolFor('XYZ'), 'XYZ');
    });

    test('byCode returns the option or null', () {
      final zar = AppCurrencies.byCode('ZAR');
      expect(zar, isNotNull);
      expect(zar!.symbol, 'R');
      expect(zar.name, 'South African Rand');

      expect(AppCurrencies.byCode('NOPE'), isNull);
    });
  });

  group('CurrencyFormatter.format', () {
    test('formats a positive amount with grouping and 2 decimals', () {
      expect(CurrencyFormatter.format('R', 1234.5), 'R1,234.50');
    });

    test('formats zero', () {
      expect(CurrencyFormatter.format('R', 0), 'R0.00');
    });

    test('keeps a leading minus before the symbol for negatives', () {
      expect(CurrencyFormatter.format('R', -1234.5), '-R1,234.50');
    });

    test('works with multi-character symbols', () {
      expect(CurrencyFormatter.format('A\$', 1000), 'A\$1,000.00');
    });
  });

  group('CurrencyFormatter.formatSigned', () {
    test('prefixes + for income', () {
      expect(
        CurrencyFormatter.formatSigned('R', 1234.5, isIncome: true),
        '+R1,234.50',
      );
    });

    test('prefixes - for expense', () {
      expect(
        CurrencyFormatter.formatSigned('R', 1234.5, isIncome: false),
        '-R1,234.50',
      );
    });

    test('uses magnitude regardless of input sign', () {
      expect(
        CurrencyFormatter.formatSigned('R', -1234.5, isIncome: true),
        '+R1,234.50',
      );
    });
  });

  group('CurrencyFormatter.formatCompact', () {
    test('formats thousands with a k suffix', () {
      expect(CurrencyFormatter.formatCompact('R', 12000), 'R12k');
    });

    test('formats fractional thousands with one decimal', () {
      expect(CurrencyFormatter.formatCompact('R', 12500), 'R12.5k');
    });

    test('formats millions with an M suffix', () {
      expect(CurrencyFormatter.formatCompact('R', 1500000), 'R1.5M');
    });

    test('formats billions with a B suffix', () {
      expect(CurrencyFormatter.formatCompact('R', 2000000000), 'R2B');
    });

    test('formats sub-thousand values without a suffix', () {
      expect(CurrencyFormatter.formatCompact('R', 500), 'R500');
    });

    test('keeps a leading minus for negatives', () {
      expect(CurrencyFormatter.formatCompact('R', -12000), '-R12k');
    });
  });
}
