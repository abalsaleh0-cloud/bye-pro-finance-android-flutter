import 'dart:async';

import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  }

  Future<void> waitForSetting(String expected) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (await database.readSetting('selected_month') == expected) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('selected_month was not persisted as $expected');
  }

  Future<void> waitForMonth(
    ProviderContainer container,
    MonthKey expected,
  ) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (container.read(selectedMonthProvider) == expected) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('selectedMonthProvider did not restore $expected');
  }

  test('restores the saved month when a new container starts', () async {
    final savedMonth = MonthKey(year: 2025, month: 8);
    await database.writeSetting('selected_month', savedMonth.toString());

    final container = createContainer();
    addTearDown(container.dispose);

    // The provider starts with the current month, then restores asynchronously.
    final initialMonth = container.read(selectedMonthProvider);
    expect(initialMonth, isNot(savedMonth));

    await waitForMonth(container, savedMonth);
    expect(container.read(selectedMonthProvider), savedMonth);
  });

  test('persists a selection and restores it in a fresh container', () async {
    final selected = MonthKey(year: 2024, month: 12);
    final firstContainer = createContainer();
    firstContainer.read(selectedMonthProvider);
    firstContainer.read(selectedMonthProvider.notifier).select(selected);

    expect(firstContainer.read(selectedMonthProvider), selected);
    await waitForSetting(selected.toString());
    firstContainer.dispose();

    final restartedContainer = createContainer();
    addTearDown(restartedContainer.dispose);
    restartedContainer.read(selectedMonthProvider);

    await waitForMonth(restartedContainer, selected);
    expect(restartedContainer.read(selectedMonthProvider), selected);
  });

  test('ignores a malformed saved month and keeps the current month', () async {
    await database.writeSetting('selected_month', '2026-13');

    final container = createContainer();
    addTearDown(container.dispose);

    final currentMonth = container.read(selectedMonthProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(container.read(selectedMonthProvider), currentMonth);
  });

  test('a late restore cannot overwrite a newer user selection', () async {
    await database.writeSetting('selected_month', '2025-01');

    final container = createContainer();
    addTearDown(container.dispose);

    container.read(selectedMonthProvider);
    final userSelection = MonthKey(year: 2026, month: 11);
    container.read(selectedMonthProvider.notifier).select(userSelection);

    await waitForSetting(userSelection.toString());
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(container.read(selectedMonthProvider), userSelection);
  });
}
