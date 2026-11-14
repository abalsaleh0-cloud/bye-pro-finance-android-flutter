import 'dart:convert';

import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/features/home/domain/home_expense_category.dart';

final class HomeExpenseCategoryRepository {
  const HomeExpenseCategoryRepository(this._database);

  final AppDatabase _database;
  static const _settingKey = 'home_expense_categories';

  Future<List<HomeExpenseCategory>> getAll() async {
    final saved = await _database.readSetting(_settingKey);
    final custom = <HomeExpenseCategory>[];
    if (saved != null && saved.isNotEmpty) {
      try {
        final decoded = jsonDecode(saved) as List<dynamic>;
        custom.addAll(
          decoded.map(
            (item) => HomeExpenseCategory.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
      } on FormatException {
        // Fall back to built-in categories if stored settings are malformed.
      } on TypeError {
        // Ignore malformed entries without blocking expense entry.
      }
    }

    final byId = <String, HomeExpenseCategory>{
      for (final category in HomeExpenseCategory.defaults) category.id: category,
    };
    for (final category in custom) {
      if (category.id.trim().isNotEmpty) byId[category.id] = category;
    }
    return byId.values.toList(growable: false);
  }

  Future<void> save(HomeExpenseCategory category) async {
    final id = category.id.trim();
    final name = category.name.trim();
    if (id.isEmpty || name.isEmpty) {
      throw ArgumentError('Category ID and name are required.');
    }
    final categories = await getAll();
    final duplicate = categories.any(
      (item) =>
          item.id != id && item.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError('A category with this name already exists.');
    }
    final updated = <String, HomeExpenseCategory>{
      for (final item in categories) item.id: item,
      id: HomeExpenseCategory(id: id, name: name),
    };
    await _database.writeSetting(
      _settingKey,
      jsonEncode(updated.values.map((item) => item.toJson()).toList()),
    );
  }
}
