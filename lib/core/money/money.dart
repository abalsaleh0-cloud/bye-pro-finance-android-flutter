/// Monetary value stored as an integer number of the smallest currency unit.
final class Money implements Comparable<Money> {
  const Money._(this.minorUnits);

  factory Money.fromMinorUnits(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Money cannot be negative.');
    }
    return Money._(value);
  }

  static const zero = Money._(0);
  final int minorUnits;
  bool get isZero => minorUnits == 0;

  Money operator +(Money other) => Money._(minorUnits + other.minorUnits);

  Money operator -(Money other) {
    final result = minorUnits - other.minorUnits;
    if (result < 0) {
      throw ArgumentError('Money subtraction cannot produce a negative value.');
    }
    return Money._(result);
  }

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => 'Money($minorUnits)';
}
