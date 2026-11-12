import 'package:expense_app/core/money/integer_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateIntegerAmount', () {
    test('adds and subtracts integer minor units', () {
      expect(calculateIntegerAmount(BigInt.from(1250), BigInt.from(250), '+'),
          BigInt.from(1500));
      expect(calculateIntegerAmount(BigInt.from(1250), BigInt.from(250), '-'),
          BigInt.from(1000));
    });

    test('multiplies large integer values without precision loss', () {
      final first = BigInt.parse('999999999999999999');
      expect(calculateIntegerAmount(first, BigInt.from(2), '×'), first * BigInt.from(2));
    });

    test('divides only when the result is an exact integer', () {
      expect(calculateIntegerAmount(BigInt.from(1000), BigInt.from(4), '÷'),
          BigInt.from(250));
      expect(calculateIntegerAmount(BigInt.from(1000), BigInt.from(3), '÷'), isNull);
      expect(calculateIntegerAmount(BigInt.from(1000), BigInt.zero, '÷'), isNull);
    });

    test('rejects unknown operations', () {
      expect(calculateIntegerAmount(BigInt.one, BigInt.one, '%'), isNull);
    });
  });
}
