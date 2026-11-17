import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WorkQuickAction { salary, payment, advance, transfer }

class WorkQuickActionController extends Notifier<WorkQuickAction?> {
  @override
  WorkQuickAction? build() => null;

  void request(WorkQuickAction action) {
    state = action;
  }

  void clear() {
    state = null;
  }
}

final workQuickActionProvider =
    NotifierProvider<WorkQuickActionController, WorkQuickAction?>(
  WorkQuickActionController.new,
);
