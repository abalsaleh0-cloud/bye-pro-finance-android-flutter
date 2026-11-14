import 'dart:math' as math;

double calculateCalculatorExpression(String source) {
  final parser = _ExpressionParser(source);
  final result = parser.parse();
  if (!result.isFinite) {
    throw const FormatException('The result is not finite.');
  }
  return result;
}

String formatCalculatorValue(double value) {
  if (value == 0) return '0';
  if (value.abs() >= 1e12 || value.abs() < 1e-8) {
    return value.toStringAsPrecision(10);
  }
  final fixed = value.toStringAsFixed(10);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// A calculator result may enter a money field only when it is a safe,
/// non-negative whole number of minor currency units.
int? calculatorValueAsMinorUnits(double value) {
  const maxExactlyRepresentableInteger = 9007199254740991;
  if (!value.isFinite ||
      value < 0 ||
      value != value.truncateToDouble() ||
      value > maxExactlyRepresentableInteger) {
    return null;
  }
  return value.toInt();
}

BigInt? calculatePercentageOfMinorUnits(
  BigInt amount,
  String percentage,
) {
  if (amount < BigInt.zero) return null;
  final parsed = _parseUnsignedDecimal(percentage);
  if (parsed == null) return null;
  return _roundHalfUp(
    amount * parsed.numerator,
    parsed.denominator * BigInt.from(100),
  );
}

BigInt? calculateDiscountedMinorUnits(
  BigInt amount,
  String percentage,
) {
  if (amount < BigInt.zero) return null;
  final parsed = _parseUnsignedDecimal(percentage);
  if (parsed == null ||
      parsed.numerator > parsed.denominator * BigInt.from(100)) {
    return null;
  }
  final discount = _roundHalfUp(
    amount * parsed.numerator,
    parsed.denominator * BigInt.from(100),
  );
  return amount - discount;
}

({BigInt perPerson, BigInt remainder})? splitMinorUnits(
  BigInt amount,
  BigInt people,
) {
  if (amount < BigInt.zero || people <= BigInt.zero) return null;
  return (
    perPerson: amount ~/ people,
    remainder: amount.remainder(people),
  );
}

BigInt _roundHalfUp(BigInt numerator, BigInt denominator) {
  final quotient = numerator ~/ denominator;
  final remainder = numerator.remainder(denominator);
  return remainder * BigInt.from(2) >= denominator
      ? quotient + BigInt.one
      : quotient;
}

({BigInt numerator, BigInt denominator})? _parseUnsignedDecimal(
  String source,
) {
  final normalized = source.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d{1,8})?$').hasMatch(normalized)) {
    return null;
  }
  final parts = normalized.split('.');
  final scale = parts.length == 1 ? 0 : parts[1].length;
  final denominator = BigInt.from(10).pow(scale);
  final whole = BigInt.parse(parts[0]);
  final fraction = scale == 0 ? BigInt.zero : BigInt.parse(parts[1]);
  return (
    numerator: whole * denominator + fraction,
    denominator: denominator,
  );
}

class _ExpressionParser {
  _ExpressionParser(this.source);

  final String source;
  int _position = 0;

  double parse() {
    if (source.trim().isEmpty) {
      throw const FormatException('Expression is empty.');
    }
    final value = _parseExpression();
    _skipWhitespace();
    if (_position != source.length) {
      throw const FormatException('Unexpected input.');
    }
    if (!value.isFinite) {
      throw const FormatException('The result is not finite.');
    }
    return value;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-') || _match('−')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parseUnary();
    while (true) {
      if (_match('*') || _match('×')) {
        value *= _parseUnary();
      } else if (_match('/') || _match('÷')) {
        final divisor = _parseUnary();
        if (divisor == 0) {
          throw const FormatException('Division by zero.');
        }
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _parseUnary() {
    if (_match('+')) return _parseUnary();
    if (_match('-') || _match('−')) return -_parseUnary();
    return _parsePower();
  }

  double _parsePower() {
    final base = _parsePostfix();
    if (_match('^')) {
      final exponent = _parseUnary();
      return math.pow(base, exponent).toDouble();
    }
    return base;
  }

  double _parsePostfix() {
    var value = _parsePrimary();
    while (_match('%')) {
      value /= 100;
    }
    return value;
  }

  double _parsePrimary() {
    _skipWhitespace();
    if (_match('√')) {
      final radicand = _parsePrimary();
      if (radicand < 0) {
        throw const FormatException('Square root of a negative value.');
      }
      return math.sqrt(radicand);
    }
    if (_match('(')) {
      final value = _parseExpression();
      if (!_match(')')) {
        throw const FormatException('Missing closing parenthesis.');
      }
      return value;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    _skipWhitespace();
    final start = _position;
    var hasDigit = false;
    while (_position < source.length && _isDigit(source.codeUnitAt(_position))) {
      hasDigit = true;
      _position++;
    }
    if (_position < source.length && source.codeUnitAt(_position) == 46) {
      _position++;
      while (_position < source.length &&
          _isDigit(source.codeUnitAt(_position))) {
        hasDigit = true;
        _position++;
      }
    }
    if (!hasDigit) {
      throw const FormatException('A number was expected.');
    }
    return double.parse(source.substring(start, _position));
  }

  bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

  bool _match(String expected) {
    _skipWhitespace();
    if (_position >= source.length ||
        source[_position] != expected) {
      return false;
    }
    _position++;
    return true;
  }

  void _skipWhitespace() {
    while (_position < source.length &&
        source[_position].trim().isEmpty) {
      _position++;
    }
  }
}
