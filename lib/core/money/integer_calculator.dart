BigInt? calculateIntegerAmount(BigInt first, BigInt second, String operation) {
  return switch (operation) {
    '+' => first + second,
    '-' => first - second,
    '×' => first * second,
    '÷' when second != BigInt.zero && first.remainder(second) == BigInt.zero =>
      first ~/ second,
    _ => null,
  };
}
