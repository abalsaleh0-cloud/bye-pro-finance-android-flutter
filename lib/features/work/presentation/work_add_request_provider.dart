import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Requests the work add-action sheet without pushing a duplicate work route.
final workAddRequestProvider =
    NotifierProvider<WorkAddRequestNotifier, int>(WorkAddRequestNotifier.new);

class WorkAddRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

enum WorkQuickAction { salary, payment, advance, transfer }
