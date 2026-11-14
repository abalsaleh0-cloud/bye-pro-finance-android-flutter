import 'package:expense_app/core/money/calculator_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculator expression engine', () {
    test('honours multiplication precedence and parentheses', () {
      expect(calculateCalculatorExpression('2 + 3 × 4'), 14);
      expect(calculateCalculatorExpression('(2 + 3) × 4'), 20);
    });

    test('supports decimals, exponents, square roots, and percentages', () {
      expect(calculateCalculatorExpression('2.5 × 4'), 10);
      expect(calculateCalculatorExpression('2^3^2'), 512);
      expect(calculateCalculatorExpression('√(81)'), 9);
      expect(calculateCalculatorExpression('25% × 80'), 20);
    });

    test('handles unary negative values and division', () {
      expect(calculateCalculatorExpression('-2^2'), -4);
      expect(calculateCalculatorExpression('18 ÷ 3'), 6);
    });

    test('rejects invalid expressions and undefined results', () {
      expect(() => calculateCalculatorExpression(''), throwsFormatException);
      expect(() => calculateCalculatorExpression('5 ÷ 0'), throwsFormatException);
      expect(() => calculateCalculatorExpression('√(-1)'), throwsFormatException);
      expect(() => calculateCalculatorExpression('(2 + 3'), throwsFormatException);
      expect(() => calculateCalculatorExpression('2 +'), throwsFormatException);
    });

    test('preserves trailing zeroes in integer results', () {
      expect(formatCalculatorValue(100), '100');
      expect(formatCalculatorValue(1000), '1000');
      expect(formatCalculatorValue(100.5), '100.5');
    });

    test('only permits safe whole non-negative values in money fields', () {
      expect(calculatorValueAsMinorUnits(42), 42);
      expect(calculatorValueAsMinorUnits(42.5), isNull);
      expect(calculatorValueAsMinorUnits(-1), isNull);
      expect(calculatorValueAsMinorUnits(9007199254740992), isNull);
    });
  });

  group('financial calculator', () {
    test('calculates a percentage using integer minor units', () {
      expect(
        calculatePercentageOfMinorUnits(BigInt.from(75000), '10'),
        BigInt.from(7500),
      );
      expect(
        calculatePercentageOfMinorUnits(BigInt.from(5), '10'),
        BigInt.one,
      );
      expect(
        calculatePercentageOfMinorUnits(BigInt.from(10000), '12.5'),
        BigInt.from(1250),
      );
    });

    test('calculates the discounted amount and rejects discounts above 100%', () {
      expect(
        calculateDiscountedMinorUnits(BigInt.from(75000), '20'),
        BigInt.from(60000),
      );
      expect(
        calculateDiscountedMinorUnits(BigInt.from(75000), '100'),
        BigInt.zero,
      );
      expect(
        calculateDiscountedMinorUnits(BigInt.from(75000), '100.01'),
        isNull,
      );
    });

    test('splits a minor-unit amount without losing its remainder', () {
      expect(
        splitMinorUnits(BigInt.from(100), BigInt.from(3)),
        (perPerson: BigInt.from(33), remainder: BigInt.one),
      );
      expect(splitMinorUnits(BigInt.from(100), BigInt.zero), isNull);
    });

    test('rejects malformed financial values', () {
      expect(
        calculatePercentageOfMinorUnits(BigInt.from(100), '-5'),
        isNull,
      );
      expect(
        calculateDiscountedMinorUnits(BigInt.from(100), 'abc'),
        isNull,
      );
    });
  });
}
