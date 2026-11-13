import 'dart:async';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, MonthKey>(
  SelectedMonthNotifier.new,
);

class SelectedMonthNotifier extends Notifier<MonthKey> {
  static const _settingKey = 'selected_month';
  int _selectionRevision = 0;

  @override
  MonthKey build() {
    final now = DateTime.now();
    _restoreSavedMonth();
    return MonthKey(year: now.year, month: now.month);
  }

  Future<void> _restoreSavedMonth() async {
    final revisionAtStart = _selectionRevision;
    try {
      final value = await ref
          .read(appDatabaseProvider)
          .readSetting(_settingKey);
      if (revisionAtStart != _selectionRevision || value == null) return;
      final parts = value.split('-');
      if (parts.length != 2) return;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null) return;
      state = MonthKey(year: year, month: month);
    } catch (_) {
      // Keep the current month if a saved preference cannot be read.
    }
  }

  void select(MonthKey month) {
    _selectionRevision++;
    state = month;
    unawaited(
      ref.read(appDatabaseProvider).writeSetting(_settingKey, month.toString()),
    );
  }
}
