import 'package:expense_app/features/settings/presentation/app_security_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not relock when returning within the 30-second grace period', () {
    final backgroundedAt = DateTime(2026, 11, 20, 10);
    expect(
      shouldRelockAfterBackground(
        backgroundedAt,
        backgroundedAt.add(const Duration(seconds: 29)),
      ),
      isFalse,
    );
  });

  test('relocks when the app remained in the background for 30 seconds', () {
    final backgroundedAt = DateTime(2026, 11, 20, 10);
    expect(
      shouldRelockAfterBackground(
        backgroundedAt,
        backgroundedAt.add(const Duration(seconds: 30)),
      ),
      isTrue,
    );
  });
}
