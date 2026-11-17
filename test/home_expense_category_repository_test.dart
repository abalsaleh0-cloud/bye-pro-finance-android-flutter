import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/features/home/data/home_expense_category_repository.dart';
import 'package:expense_app/features/home/domain/home_expense_category.dart';

void main() {
  late AppDatabase database;
  late HomeExpenseCategoryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = HomeExpenseCategoryRepository(database);
  });

  tearDown(() async => database.close());

  test('provides the fourteen built-in household categories', () async {
    final categories = await repository.getAll();
    expect(categories.map((item) => item.id), [
      'groceries',
      'utilities',
      'housing',
      'cleaning',
      'maintenance',
      'transport',
      'personal',
      'health',
      'education',
      'communications',
      'entertainment',
      'clothing',
      'gifts',
      'other',
    ]);
  });

  test('persists custom categories and edits built-in labels', () async {
    await repository.save(
      const HomeExpenseCategory(id: 'groceries', name: 'Food and groceries'),
    );
    await repository.save(
      const HomeExpenseCategory(id: 'custom-1', name: 'School supplies'),
    );

    final categories = await repository.getAll();
    expect(categories, hasLength(15));
    expect(
      categories.singleWhere((item) => item.id == 'groceries').name,
      'Food and groceries',
    );
    expect(
      categories.singleWhere((item) => item.id == 'custom-1').name,
      'School supplies',
    );
  });

  test('persists a custom category icon selection', () async {
    await repository.save(
      const HomeExpenseCategory(
        id: 'custom-travel',
        name: 'Travel',
        iconKey: 'transport',
      ),
    );

    final saved = (await repository.getAll())
        .singleWhere((item) => item.id == 'custom-travel');
    expect(saved.iconKey, 'transport');
  });

  test('rejects duplicate category names', () async {
    await repository.save(
      const HomeExpenseCategory(id: 'custom-1', name: 'School'),
    );
    await expectLater(
      repository.save(
        const HomeExpenseCategory(id: 'custom-2', name: ' school '),
      ),
      throwsArgumentError,
    );
  });
}
