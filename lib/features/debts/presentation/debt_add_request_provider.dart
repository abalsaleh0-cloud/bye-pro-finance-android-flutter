import 'package:flutter_riverpod/flutter_riverpod.dart';

final debtAddRequestProvider =
    NotifierProvider<DebtAddRequestNotifier, int>(DebtAddRequestNotifier.new);

class DebtAddRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
