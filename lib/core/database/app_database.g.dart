// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HomeExpensesTable extends HomeExpenses
    with TableInfo<$HomeExpensesTable, HomeExpenseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HomeExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expenseDateEpochMillisMeta =
      const VerificationMeta('expenseDateEpochMillis');
  @override
  late final GeneratedColumn<int> expenseDateEpochMillis = GeneratedColumn<int>(
    'expense_date_epoch_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueYearMeta = const VerificationMeta(
    'dueYear',
  );
  @override
  late final GeneratedColumn<int> dueYear = GeneratedColumn<int>(
    'due_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueMonthMeta = const VerificationMeta(
    'dueMonth',
  );
  @override
  late final GeneratedColumn<int> dueMonth = GeneratedColumn<int>(
    'due_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    amountMinorUnits,
    categoryId,
    expenseDateEpochMillis,
    dueYear,
    dueMonth,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'home_expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<HomeExpenseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('expense_date_epoch_millis')) {
      context.handle(
        _expenseDateEpochMillisMeta,
        expenseDateEpochMillis.isAcceptableOrUnknown(
          data['expense_date_epoch_millis']!,
          _expenseDateEpochMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expenseDateEpochMillisMeta);
    }
    if (data.containsKey('due_year')) {
      context.handle(
        _dueYearMeta,
        dueYear.isAcceptableOrUnknown(data['due_year']!, _dueYearMeta),
      );
    } else if (isInserting) {
      context.missing(_dueYearMeta);
    }
    if (data.containsKey('due_month')) {
      context.handle(
        _dueMonthMeta,
        dueMonth.isAcceptableOrUnknown(data['due_month']!, _dueMonthMeta),
      );
    } else if (isInserting) {
      context.missing(_dueMonthMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HomeExpenseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HomeExpenseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      expenseDateEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expense_date_epoch_millis'],
      )!,
      dueYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_year'],
      )!,
      dueMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_month'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $HomeExpensesTable createAlias(String alias) {
    return $HomeExpensesTable(attachedDatabase, alias);
  }
}

class HomeExpenseRow extends DataClass implements Insertable<HomeExpenseRow> {
  final String id;
  final int amountMinorUnits;
  final String categoryId;
  final int expenseDateEpochMillis;
  final int dueYear;
  final int dueMonth;
  final String? note;
  const HomeExpenseRow({
    required this.id,
    required this.amountMinorUnits,
    required this.categoryId,
    required this.expenseDateEpochMillis,
    required this.dueYear,
    required this.dueMonth,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['category_id'] = Variable<String>(categoryId);
    map['expense_date_epoch_millis'] = Variable<int>(expenseDateEpochMillis);
    map['due_year'] = Variable<int>(dueYear);
    map['due_month'] = Variable<int>(dueMonth);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  HomeExpensesCompanion toCompanion(bool nullToAbsent) {
    return HomeExpensesCompanion(
      id: Value(id),
      amountMinorUnits: Value(amountMinorUnits),
      categoryId: Value(categoryId),
      expenseDateEpochMillis: Value(expenseDateEpochMillis),
      dueYear: Value(dueYear),
      dueMonth: Value(dueMonth),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory HomeExpenseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HomeExpenseRow(
      id: serializer.fromJson<String>(json['id']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      expenseDateEpochMillis: serializer.fromJson<int>(
        json['expenseDateEpochMillis'],
      ),
      dueYear: serializer.fromJson<int>(json['dueYear']),
      dueMonth: serializer.fromJson<int>(json['dueMonth']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'categoryId': serializer.toJson<String>(categoryId),
      'expenseDateEpochMillis': serializer.toJson<int>(expenseDateEpochMillis),
      'dueYear': serializer.toJson<int>(dueYear),
      'dueMonth': serializer.toJson<int>(dueMonth),
      'note': serializer.toJson<String?>(note),
    };
  }

  HomeExpenseRow copyWith({
    String? id,
    int? amountMinorUnits,
    String? categoryId,
    int? expenseDateEpochMillis,
    int? dueYear,
    int? dueMonth,
    Value<String?> note = const Value.absent(),
  }) => HomeExpenseRow(
    id: id ?? this.id,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    categoryId: categoryId ?? this.categoryId,
    expenseDateEpochMillis:
        expenseDateEpochMillis ?? this.expenseDateEpochMillis,
    dueYear: dueYear ?? this.dueYear,
    dueMonth: dueMonth ?? this.dueMonth,
    note: note.present ? note.value : this.note,
  );
  HomeExpenseRow copyWithCompanion(HomeExpensesCompanion data) {
    return HomeExpenseRow(
      id: data.id.present ? data.id.value : this.id,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      expenseDateEpochMillis: data.expenseDateEpochMillis.present
          ? data.expenseDateEpochMillis.value
          : this.expenseDateEpochMillis,
      dueYear: data.dueYear.present ? data.dueYear.value : this.dueYear,
      dueMonth: data.dueMonth.present ? data.dueMonth.value : this.dueMonth,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HomeExpenseRow(')
          ..write('id: $id, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('categoryId: $categoryId, ')
          ..write('expenseDateEpochMillis: $expenseDateEpochMillis, ')
          ..write('dueYear: $dueYear, ')
          ..write('dueMonth: $dueMonth, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    amountMinorUnits,
    categoryId,
    expenseDateEpochMillis,
    dueYear,
    dueMonth,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HomeExpenseRow &&
          other.id == this.id &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.categoryId == this.categoryId &&
          other.expenseDateEpochMillis == this.expenseDateEpochMillis &&
          other.dueYear == this.dueYear &&
          other.dueMonth == this.dueMonth &&
          other.note == this.note);
}

class HomeExpensesCompanion extends UpdateCompanion<HomeExpenseRow> {
  final Value<String> id;
  final Value<int> amountMinorUnits;
  final Value<String> categoryId;
  final Value<int> expenseDateEpochMillis;
  final Value<int> dueYear;
  final Value<int> dueMonth;
  final Value<String?> note;
  final Value<int> rowid;
  const HomeExpensesCompanion({
    this.id = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.expenseDateEpochMillis = const Value.absent(),
    this.dueYear = const Value.absent(),
    this.dueMonth = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HomeExpensesCompanion.insert({
    required String id,
    required int amountMinorUnits,
    required String categoryId,
    required int expenseDateEpochMillis,
    required int dueYear,
    required int dueMonth,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amountMinorUnits = Value(amountMinorUnits),
       categoryId = Value(categoryId),
       expenseDateEpochMillis = Value(expenseDateEpochMillis),
       dueYear = Value(dueYear),
       dueMonth = Value(dueMonth);
  static Insertable<HomeExpenseRow> custom({
    Expression<String>? id,
    Expression<int>? amountMinorUnits,
    Expression<String>? categoryId,
    Expression<int>? expenseDateEpochMillis,
    Expression<int>? dueYear,
    Expression<int>? dueMonth,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (categoryId != null) 'category_id': categoryId,
      if (expenseDateEpochMillis != null)
        'expense_date_epoch_millis': expenseDateEpochMillis,
      if (dueYear != null) 'due_year': dueYear,
      if (dueMonth != null) 'due_month': dueMonth,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HomeExpensesCompanion copyWith({
    Value<String>? id,
    Value<int>? amountMinorUnits,
    Value<String>? categoryId,
    Value<int>? expenseDateEpochMillis,
    Value<int>? dueYear,
    Value<int>? dueMonth,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return HomeExpensesCompanion(
      id: id ?? this.id,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      categoryId: categoryId ?? this.categoryId,
      expenseDateEpochMillis:
          expenseDateEpochMillis ?? this.expenseDateEpochMillis,
      dueYear: dueYear ?? this.dueYear,
      dueMonth: dueMonth ?? this.dueMonth,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (expenseDateEpochMillis.present) {
      map['expense_date_epoch_millis'] = Variable<int>(
        expenseDateEpochMillis.value,
      );
    }
    if (dueYear.present) {
      map['due_year'] = Variable<int>(dueYear.value);
    }
    if (dueMonth.present) {
      map['due_month'] = Variable<int>(dueMonth.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HomeExpensesCompanion(')
          ..write('id: $id, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('categoryId: $categoryId, ')
          ..write('expenseDateEpochMillis: $expenseDateEpochMillis, ')
          ..write('dueYear: $dueYear, ')
          ..write('dueMonth: $dueMonth, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkEntriesTable extends WorkEntries
    with TableInfo<$WorkEntriesTable, WorkEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueYearMeta = const VerificationMeta(
    'dueYear',
  );
  @override
  late final GeneratedColumn<int> dueYear = GeneratedColumn<int>(
    'due_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueMonthMeta = const VerificationMeta(
    'dueMonth',
  );
  @override
  late final GeneratedColumn<int> dueMonth = GeneratedColumn<int>(
    'due_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtEpochMillisMeta =
      const VerificationMeta('recordedAtEpochMillis');
  @override
  late final GeneratedColumn<int> recordedAtEpochMillis = GeneratedColumn<int>(
    'recorded_at_epoch_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    amountMinorUnits,
    dueYear,
    dueMonth,
    recordedAtEpochMillis,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('due_year')) {
      context.handle(
        _dueYearMeta,
        dueYear.isAcceptableOrUnknown(data['due_year']!, _dueYearMeta),
      );
    } else if (isInserting) {
      context.missing(_dueYearMeta);
    }
    if (data.containsKey('due_month')) {
      context.handle(
        _dueMonthMeta,
        dueMonth.isAcceptableOrUnknown(data['due_month']!, _dueMonthMeta),
      );
    } else if (isInserting) {
      context.missing(_dueMonthMeta);
    }
    if (data.containsKey('recorded_at_epoch_millis')) {
      context.handle(
        _recordedAtEpochMillisMeta,
        recordedAtEpochMillis.isAcceptableOrUnknown(
          data['recorded_at_epoch_millis']!,
          _recordedAtEpochMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtEpochMillisMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      dueYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_year'],
      )!,
      dueMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_month'],
      )!,
      recordedAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at_epoch_millis'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $WorkEntriesTable createAlias(String alias) {
    return $WorkEntriesTable(attachedDatabase, alias);
  }
}

class WorkEntryRow extends DataClass implements Insertable<WorkEntryRow> {
  final String id;
  final String kind;
  final int amountMinorUnits;
  final int dueYear;
  final int dueMonth;
  final int recordedAtEpochMillis;
  final String? note;
  const WorkEntryRow({
    required this.id,
    required this.kind,
    required this.amountMinorUnits,
    required this.dueYear,
    required this.dueMonth,
    required this.recordedAtEpochMillis,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['due_year'] = Variable<int>(dueYear);
    map['due_month'] = Variable<int>(dueMonth);
    map['recorded_at_epoch_millis'] = Variable<int>(recordedAtEpochMillis);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  WorkEntriesCompanion toCompanion(bool nullToAbsent) {
    return WorkEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      amountMinorUnits: Value(amountMinorUnits),
      dueYear: Value(dueYear),
      dueMonth: Value(dueMonth),
      recordedAtEpochMillis: Value(recordedAtEpochMillis),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory WorkEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkEntryRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      dueYear: serializer.fromJson<int>(json['dueYear']),
      dueMonth: serializer.fromJson<int>(json['dueMonth']),
      recordedAtEpochMillis: serializer.fromJson<int>(
        json['recordedAtEpochMillis'],
      ),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'dueYear': serializer.toJson<int>(dueYear),
      'dueMonth': serializer.toJson<int>(dueMonth),
      'recordedAtEpochMillis': serializer.toJson<int>(recordedAtEpochMillis),
      'note': serializer.toJson<String?>(note),
    };
  }

  WorkEntryRow copyWith({
    String? id,
    String? kind,
    int? amountMinorUnits,
    int? dueYear,
    int? dueMonth,
    int? recordedAtEpochMillis,
    Value<String?> note = const Value.absent(),
  }) => WorkEntryRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    dueYear: dueYear ?? this.dueYear,
    dueMonth: dueMonth ?? this.dueMonth,
    recordedAtEpochMillis: recordedAtEpochMillis ?? this.recordedAtEpochMillis,
    note: note.present ? note.value : this.note,
  );
  WorkEntryRow copyWithCompanion(WorkEntriesCompanion data) {
    return WorkEntryRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      dueYear: data.dueYear.present ? data.dueYear.value : this.dueYear,
      dueMonth: data.dueMonth.present ? data.dueMonth.value : this.dueMonth,
      recordedAtEpochMillis: data.recordedAtEpochMillis.present
          ? data.recordedAtEpochMillis.value
          : this.recordedAtEpochMillis,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkEntryRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('dueYear: $dueYear, ')
          ..write('dueMonth: $dueMonth, ')
          ..write('recordedAtEpochMillis: $recordedAtEpochMillis, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    amountMinorUnits,
    dueYear,
    dueMonth,
    recordedAtEpochMillis,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkEntryRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.dueYear == this.dueYear &&
          other.dueMonth == this.dueMonth &&
          other.recordedAtEpochMillis == this.recordedAtEpochMillis &&
          other.note == this.note);
}

class WorkEntriesCompanion extends UpdateCompanion<WorkEntryRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<int> amountMinorUnits;
  final Value<int> dueYear;
  final Value<int> dueMonth;
  final Value<int> recordedAtEpochMillis;
  final Value<String?> note;
  final Value<int> rowid;
  const WorkEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.dueYear = const Value.absent(),
    this.dueMonth = const Value.absent(),
    this.recordedAtEpochMillis = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkEntriesCompanion.insert({
    required String id,
    required String kind,
    required int amountMinorUnits,
    required int dueYear,
    required int dueMonth,
    required int recordedAtEpochMillis,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       amountMinorUnits = Value(amountMinorUnits),
       dueYear = Value(dueYear),
       dueMonth = Value(dueMonth),
       recordedAtEpochMillis = Value(recordedAtEpochMillis);
  static Insertable<WorkEntryRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<int>? amountMinorUnits,
    Expression<int>? dueYear,
    Expression<int>? dueMonth,
    Expression<int>? recordedAtEpochMillis,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (dueYear != null) 'due_year': dueYear,
      if (dueMonth != null) 'due_month': dueMonth,
      if (recordedAtEpochMillis != null)
        'recorded_at_epoch_millis': recordedAtEpochMillis,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<int>? amountMinorUnits,
    Value<int>? dueYear,
    Value<int>? dueMonth,
    Value<int>? recordedAtEpochMillis,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return WorkEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      dueYear: dueYear ?? this.dueYear,
      dueMonth: dueMonth ?? this.dueMonth,
      recordedAtEpochMillis:
          recordedAtEpochMillis ?? this.recordedAtEpochMillis,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (dueYear.present) {
      map['due_year'] = Variable<int>(dueYear.value);
    }
    if (dueMonth.present) {
      map['due_month'] = Variable<int>(dueMonth.value);
    }
    if (recordedAtEpochMillis.present) {
      map['recorded_at_epoch_millis'] = Variable<int>(
        recordedAtEpochMillis.value,
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('dueYear: $dueYear, ')
          ..write('dueMonth: $dueMonth, ')
          ..write('recordedAtEpochMillis: $recordedAtEpochMillis, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkHomeTransfersTable extends WorkHomeTransfers
    with TableInfo<$WorkHomeTransfersTable, WorkHomeTransferRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkHomeTransfersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transferredAtEpochMillisMeta =
      const VerificationMeta('transferredAtEpochMillis');
  @override
  late final GeneratedColumn<int> transferredAtEpochMillis =
      GeneratedColumn<int>(
        'transferred_at_epoch_millis',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    amountMinorUnits,
    transferredAtEpochMillis,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'work_home_transfers';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkHomeTransferRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('transferred_at_epoch_millis')) {
      context.handle(
        _transferredAtEpochMillisMeta,
        transferredAtEpochMillis.isAcceptableOrUnknown(
          data['transferred_at_epoch_millis']!,
          _transferredAtEpochMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transferredAtEpochMillisMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkHomeTransferRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkHomeTransferRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      transferredAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transferred_at_epoch_millis'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $WorkHomeTransfersTable createAlias(String alias) {
    return $WorkHomeTransfersTable(attachedDatabase, alias);
  }
}

class WorkHomeTransferRow extends DataClass
    implements Insertable<WorkHomeTransferRow> {
  final String id;
  final int amountMinorUnits;
  final int transferredAtEpochMillis;
  final String? note;
  const WorkHomeTransferRow({
    required this.id,
    required this.amountMinorUnits,
    required this.transferredAtEpochMillis,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['transferred_at_epoch_millis'] = Variable<int>(
      transferredAtEpochMillis,
    );
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  WorkHomeTransfersCompanion toCompanion(bool nullToAbsent) {
    return WorkHomeTransfersCompanion(
      id: Value(id),
      amountMinorUnits: Value(amountMinorUnits),
      transferredAtEpochMillis: Value(transferredAtEpochMillis),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory WorkHomeTransferRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkHomeTransferRow(
      id: serializer.fromJson<String>(json['id']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      transferredAtEpochMillis: serializer.fromJson<int>(
        json['transferredAtEpochMillis'],
      ),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'transferredAtEpochMillis': serializer.toJson<int>(
        transferredAtEpochMillis,
      ),
      'note': serializer.toJson<String?>(note),
    };
  }

  WorkHomeTransferRow copyWith({
    String? id,
    int? amountMinorUnits,
    int? transferredAtEpochMillis,
    Value<String?> note = const Value.absent(),
  }) => WorkHomeTransferRow(
    id: id ?? this.id,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    transferredAtEpochMillis:
        transferredAtEpochMillis ?? this.transferredAtEpochMillis,
    note: note.present ? note.value : this.note,
  );
  WorkHomeTransferRow copyWithCompanion(WorkHomeTransfersCompanion data) {
    return WorkHomeTransferRow(
      id: data.id.present ? data.id.value : this.id,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      transferredAtEpochMillis: data.transferredAtEpochMillis.present
          ? data.transferredAtEpochMillis.value
          : this.transferredAtEpochMillis,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkHomeTransferRow(')
          ..write('id: $id, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('transferredAtEpochMillis: $transferredAtEpochMillis, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, amountMinorUnits, transferredAtEpochMillis, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkHomeTransferRow &&
          other.id == this.id &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.transferredAtEpochMillis == this.transferredAtEpochMillis &&
          other.note == this.note);
}

class WorkHomeTransfersCompanion extends UpdateCompanion<WorkHomeTransferRow> {
  final Value<String> id;
  final Value<int> amountMinorUnits;
  final Value<int> transferredAtEpochMillis;
  final Value<String?> note;
  final Value<int> rowid;
  const WorkHomeTransfersCompanion({
    this.id = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.transferredAtEpochMillis = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkHomeTransfersCompanion.insert({
    required String id,
    required int amountMinorUnits,
    required int transferredAtEpochMillis,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amountMinorUnits = Value(amountMinorUnits),
       transferredAtEpochMillis = Value(transferredAtEpochMillis);
  static Insertable<WorkHomeTransferRow> custom({
    Expression<String>? id,
    Expression<int>? amountMinorUnits,
    Expression<int>? transferredAtEpochMillis,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (transferredAtEpochMillis != null)
        'transferred_at_epoch_millis': transferredAtEpochMillis,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkHomeTransfersCompanion copyWith({
    Value<String>? id,
    Value<int>? amountMinorUnits,
    Value<int>? transferredAtEpochMillis,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return WorkHomeTransfersCompanion(
      id: id ?? this.id,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      transferredAtEpochMillis:
          transferredAtEpochMillis ?? this.transferredAtEpochMillis,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (transferredAtEpochMillis.present) {
      map['transferred_at_epoch_millis'] = Variable<int>(
        transferredAtEpochMillis.value,
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkHomeTransfersCompanion(')
          ..write('id: $id, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('transferredAtEpochMillis: $transferredAtEpochMillis, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtsTable extends Debts with TableInfo<$DebtsTable, DebtRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalAmountMinorUnitsMeta =
      const VerificationMeta('originalAmountMinorUnits');
  @override
  late final GeneratedColumn<int> originalAmountMinorUnits =
      GeneratedColumn<int>(
        'original_amount_minor_units',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _outstandingAmountMinorUnitsMeta =
      const VerificationMeta('outstandingAmountMinorUnits');
  @override
  late final GeneratedColumn<int> outstandingAmountMinorUnits =
      GeneratedColumn<int>(
        'outstanding_amount_minor_units',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _dueYearMeta = const VerificationMeta(
    'dueYear',
  );
  @override
  late final GeneratedColumn<int> dueYear = GeneratedColumn<int>(
    'due_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueMonthMeta = const VerificationMeta(
    'dueMonth',
  );
  @override
  late final GeneratedColumn<int> dueMonth = GeneratedColumn<int>(
    'due_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtEpochMillisMeta =
      const VerificationMeta('createdAtEpochMillis');
  @override
  late final GeneratedColumn<int> createdAtEpochMillis = GeneratedColumn<int>(
    'created_at_epoch_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterpartyMeta = const VerificationMeta(
    'counterparty',
  );
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
    'counterparty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    direction,
    originalAmountMinorUnits,
    outstandingAmountMinorUnits,
    dueYear,
    dueMonth,
    createdAtEpochMillis,
    counterparty,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebtRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('original_amount_minor_units')) {
      context.handle(
        _originalAmountMinorUnitsMeta,
        originalAmountMinorUnits.isAcceptableOrUnknown(
          data['original_amount_minor_units']!,
          _originalAmountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalAmountMinorUnitsMeta);
    }
    if (data.containsKey('outstanding_amount_minor_units')) {
      context.handle(
        _outstandingAmountMinorUnitsMeta,
        outstandingAmountMinorUnits.isAcceptableOrUnknown(
          data['outstanding_amount_minor_units']!,
          _outstandingAmountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outstandingAmountMinorUnitsMeta);
    }
    if (data.containsKey('due_year')) {
      context.handle(
        _dueYearMeta,
        dueYear.isAcceptableOrUnknown(data['due_year']!, _dueYearMeta),
      );
    } else if (isInserting) {
      context.missing(_dueYearMeta);
    }
    if (data.containsKey('due_month')) {
      context.handle(
        _dueMonthMeta,
        dueMonth.isAcceptableOrUnknown(data['due_month']!, _dueMonthMeta),
      );
    } else if (isInserting) {
      context.missing(_dueMonthMeta);
    }
    if (data.containsKey('created_at_epoch_millis')) {
      context.handle(
        _createdAtEpochMillisMeta,
        createdAtEpochMillis.isAcceptableOrUnknown(
          data['created_at_epoch_millis']!,
          _createdAtEpochMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMillisMeta);
    }
    if (data.containsKey('counterparty')) {
      context.handle(
        _counterpartyMeta,
        counterparty.isAcceptableOrUnknown(
          data['counterparty']!,
          _counterpartyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_counterpartyMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DebtRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      originalAmountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_amount_minor_units'],
      )!,
      outstandingAmountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}outstanding_amount_minor_units'],
      )!,
      dueYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_year'],
      )!,
      dueMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_month'],
      )!,
      createdAtEpochMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_millis'],
      )!,
      counterparty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $DebtsTable createAlias(String alias) {
    return $DebtsTable(attachedDatabase, alias);
  }
}

class DebtRow extends DataClass implements Insertable<DebtRow> {
  final String id;
  final String direction;
  final int originalAmountMinorUnits;
  final int outstandingAmountMinorUnits;
  final int dueYear;
  final int dueMonth;
  final int createdAtEpochMillis;
  final String counterparty;
  final String? note;
  const DebtRow({
    required this.id,
    required this.direction,
    required this.originalAmountMinorUnits,
    required this.outstandingAmountMinorUnits,
    required this.dueYear,
    required this.dueMonth,
    required this.createdAtEpochMillis,
    required this.counterparty,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['direction'] = Variable<String>(direction);
    map['original_amount_minor_units'] = Variable<int>(
      originalAmountMinorUnits,
    );
    map['outstanding_amount_minor_units'] = Variable<int>(
      outstandingAmountMinorUnits,
    );
    map['due_year'] = Variable<int>(dueYear);
    map['due_month'] = Variable<int>(dueMonth);
    map['created_at_epoch_millis'] = Variable<int>(createdAtEpochMillis);
    map['counterparty'] = Variable<String>(counterparty);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  DebtsCompanion toCompanion(bool nullToAbsent) {
    return DebtsCompanion(
      id: Value(id),
      direction: Value(direction),
      originalAmountMinorUnits: Value(originalAmountMinorUnits),
      outstandingAmountMinorUnits: Value(outstandingAmountMinorUnits),
      dueYear: Value(dueYear),
      dueMonth: Value(dueMonth),
      createdAtEpochMillis: Value(createdAtEpochMillis),
      counterparty: Value(counterparty),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory DebtRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtRow(
      id: serializer.fromJson<String>(json['id']),
      direction: serializer.fromJson<String>(json['direction']),
      originalAmountMinorUnits: serializer.fromJson<int>(
        json['originalAmountMinorUnits'],
      ),
      outstandingAmountMinorUnits: serializer.fromJson<int>(
        json['outstandingAmountMinorUnits'],
      ),
      dueYear: serializer.fromJson<int>(json['dueYear']),
      dueMonth: serializer.fromJson<int>(json['dueMonth']),
      createdAtEpochMillis: serializer.fromJson<int>(
        json['createdAtEpochMillis'],
      ),
      counterparty: serializer.fromJson<String>(json['counterparty']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'direction': serializer.toJson<String>(direction),
      'originalAmountMinorUnits': serializer.toJson<int>(
        originalAmountMinorUnits,
      ),
      'outstandingAmountMinorUnits': serializer.toJson<int>(
        outstandingAmountMinorUnits,
      ),
      'dueYear': serializer.toJson<int>(dueYear),
      'dueMonth': serializer.toJson<int>(dueMonth),
      'createdAtEpochMillis': serializer.toJson<int>(createdAtEpochMillis),
      'counterparty': serializer.toJson<String>(counterparty),
      'note': serializer.toJson<String?>(note),
    };
  }

  DebtRow copyWith({
    String? id,
    String? direction,
    int? originalAmountMinorUnits,
    int? outstandingAmountMinorUnits,
    int? dueYear,
    int? dueMonth,
    int? createdAtEpochMillis,
    String? counterparty,
    Value<String?> note = const Value.absent(),
  }) => DebtRow(
    id: id ?? this.id,
    direction: direction ?? this.direction,
    originalAmountMinorUnits:
        originalAmountMinorUnits ?? this.originalAmountMinorUnits,
    outstandingAmountMinorUnits:
        outstandingAmountMinorUnits ?? this.outstandingAmountMinorUnits,
    dueYear: dueYear ?? this.dueYear,
    dueMonth: dueMonth ?? this.dueMonth,
    createdAtEpochMillis: createdAtEpochMillis ?? this.createdAtEpochMillis,
    counterparty: counterparty ?? this.counterparty,
    note: note.present ? note.value : this.note,
  );
  DebtRow copyWithCompanion(DebtsCompanion data) {
    return DebtRow(
      id: data.id.present ? data.id.value : this.id,
      direction: data.direction.present ? data.direction.value : this.direction,
      originalAmountMinorUnits: data.originalAmountMinorUnits.present
          ? data.originalAmountMinorUnits.value
          : this.originalAmountMinorUnits,
      outstandingAmountMinorUnits: data.outstandingAmountMinorUnits.present
          ? data.outstandingAmountMinorUnits.value
          : this.outstandingAmountMinorUnits,
      dueYear: data.dueYear.present ? data.dueYear.value : this.dueYear,
      dueMonth: data.dueMonth.present ? data.dueMonth.value : this.dueMonth,
      createdAtEpochMillis: data.createdAtEpochMillis.present
          ? data.createdAtEpochMillis.value
          : this.createdAtEpochMillis,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtRow(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('originalAmountMinorUnits: $originalAmountMinorUnits, ')
          ..write('outstandingAmountMinorUnits: $outstandingAmountMinorUnits, ')
          ..write('dueYear: $dueYear, ')
          ..write('dueMonth: $dueMonth, ')
          ..write('createdAtEpochMillis: $createdAtEpochMillis, ')
          ..write('counterparty: $counterparty, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    direction,
    originalAmountMinorUnits,
    outstandingAmountMinorUnits,
    dueYear,
    dueMonth,
    createdAtEpochMillis,
    counterparty,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtRow &&
          other.id == this.id &&
          other.direction == this.direction &&
          other.originalAmountMinorUnits == this.originalAmountMinorUnits &&
          other.outstandingAmountMinorUnits ==
              this.outstandingAmountMinorUnits &&
          other.dueYear == this.dueYear &&
          other.dueMonth == this.dueMonth &&
          other.createdAtEpochMillis == this.createdAtEpochMillis &&
          other.counterparty == this.counterparty &&
          other.note == this.note);
}

class DebtsCompanion extends UpdateCompanion<DebtRow> {
  final Value<String> id;
  final Value<String> direction;
  final Value<int> originalAmountMinorUnits;
  final Value<int> outstandingAmountMinorUnits;
  final Value<int> dueYear;
  final Value<int> dueMonth;
  final Value<int> createdAtEpochMillis;
  final Value<String> counterparty;
  final Value<String?> note;
  final Value<int> rowid;
  const DebtsCompanion({
    this.id = const Value.absent(),
    this.direction = const Value.absent(),
    this.originalAmountMinorUnits = const Value.absent(),
    this.outstandingAmountMinorUnits = const Value.absent(),
    this.dueYear = const Value.absent(),
    this.dueMonth = const Value.absent(),
    this.createdAtEpochMillis = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtsCompanion.insert({
    required String id,
    required String direction,
    required int originalAmountMinorUnits,
    required int outstandingAmountMinorUnits,
    required int dueYear,
    required int dueMonth,
    required int createdAtEpochMillis,
    required String counterparty,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       direction = Value(direction),
       originalAmountMinorUnits = Value(originalAmountMinorUnits),
       outstandingAmountMinorUnits = Value(outstandingAmountMinorUnits),
       dueYear = Value(dueYear),
       dueMonth = Value(dueMonth),
       createdAtEpochMillis = Value(createdAtEpochMillis),
       counterparty = Value(counterparty);
  static Insertable<DebtRow> custom({
    Expression<String>? id,
    Expression<String>? direction,
    Expression<int>? originalAmountMinorUnits,
    Expression<int>? outstandingAmountMinorUnits,
    Expression<int>? dueYear,
    Expression<int>? dueMonth,
    Expression<int>? createdAtEpochMillis,
    Expression<String>? counterparty,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (direction != null) 'direction': direction,
      if (originalAmountMinorUnits != null)
        'original_amount_minor_units': originalAmountMinorUnits,
      if (outstandingAmountMinorUnits != null)
        'outstanding_amount_minor_units': outstandingAmountMinorUnits,
      if (dueYear != null) 'due_year': dueYear,
      if (dueMonth != null) 'due_month': dueMonth,
      if (createdAtEpochMillis != null)
        'created_at_epoch_millis': createdAtEpochMillis,
      if (counterparty != null) 'counterparty': counterparty,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtsCompanion copyWith({
    Value<String>? id,
    Value<String>? direction,
    Value<int>? originalAmountMinorUnits,
    Value<int>? outstandingAmountMinorUnits,
    Value<int>? dueYear,
    Value<int>? dueMonth,
    Value<int>? createdAtEpochMillis,
    Value<String>? counterparty,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return DebtsCompanion(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      originalAmountMinorUnits:
          originalAmountMinorUnits ?? this.originalAmountMinorUnits,
      outstandingAmountMinorUnits:
          outstandingAmountMinorUnits ?? this.outstandingAmountMinorUnits,
      dueYear: dueYear ?? this.dueYear,
      dueMonth: dueMonth ?? this.dueMonth,
      createdAtEpochMillis: createdAtEpochMillis ?? this.createdAtEpochMillis,
      counterparty: counterparty ?? this.counterparty,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (originalAmountMinorUnits.present) {
      map['original_amount_minor_units'] = Variable<int>(
        originalAmountMinorUnits.value,
      );
    }
    if (outstandingAmountMinorUnits.present) {
      map['outstanding_amount_minor_units'] = Variable<int>(
        outstandingAmountMinorUnits.value,
      );
    }
    if (dueYear.present) {
      map['due_year'] = Variable<int>(dueYear.value);
    }
    if (dueMonth.present) {
      map['due_month'] = Variable<int>(dueMonth.value);
    }
    if (createdAtEpochMillis.present) {
      map['created_at_epoch_millis'] = Variable<int>(
        createdAtEpochMillis.value,
      );
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtsCompanion(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('originalAmountMinorUnits: $originalAmountMinorUnits, ')
          ..write('outstandingAmountMinorUnits: $outstandingAmountMinorUnits, ')
          ..write('dueYear: $dueYear, ')
          ..write('dueMonth: $dueMonth, ')
          ..write('createdAtEpochMillis: $createdAtEpochMillis, ')
          ..write('counterparty: $counterparty, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HomeExpensesTable homeExpenses = $HomeExpensesTable(this);
  late final $WorkEntriesTable workEntries = $WorkEntriesTable(this);
  late final $WorkHomeTransfersTable workHomeTransfers =
      $WorkHomeTransfersTable(this);
  late final $DebtsTable debts = $DebtsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    homeExpenses,
    workEntries,
    workHomeTransfers,
    debts,
  ];
}

typedef $$HomeExpensesTableCreateCompanionBuilder =
    HomeExpensesCompanion Function({
      required String id,
      required int amountMinorUnits,
      required String categoryId,
      required int expenseDateEpochMillis,
      required int dueYear,
      required int dueMonth,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$HomeExpensesTableUpdateCompanionBuilder =
    HomeExpensesCompanion Function({
      Value<String> id,
      Value<int> amountMinorUnits,
      Value<String> categoryId,
      Value<int> expenseDateEpochMillis,
      Value<int> dueYear,
      Value<int> dueMonth,
      Value<String?> note,
      Value<int> rowid,
    });

class $$HomeExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $HomeExpensesTable> {
  $$HomeExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expenseDateEpochMillis => $composableBuilder(
    column: $table.expenseDateEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueYear => $composableBuilder(
    column: $table.dueYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueMonth => $composableBuilder(
    column: $table.dueMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HomeExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $HomeExpensesTable> {
  $$HomeExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expenseDateEpochMillis => $composableBuilder(
    column: $table.expenseDateEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueYear => $composableBuilder(
    column: $table.dueYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueMonth => $composableBuilder(
    column: $table.dueMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HomeExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HomeExpensesTable> {
  $$HomeExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expenseDateEpochMillis => $composableBuilder(
    column: $table.expenseDateEpochMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueYear =>
      $composableBuilder(column: $table.dueYear, builder: (column) => column);

  GeneratedColumn<int> get dueMonth =>
      $composableBuilder(column: $table.dueMonth, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$HomeExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HomeExpensesTable,
          HomeExpenseRow,
          $$HomeExpensesTableFilterComposer,
          $$HomeExpensesTableOrderingComposer,
          $$HomeExpensesTableAnnotationComposer,
          $$HomeExpensesTableCreateCompanionBuilder,
          $$HomeExpensesTableUpdateCompanionBuilder,
          (
            HomeExpenseRow,
            BaseReferences<_$AppDatabase, $HomeExpensesTable, HomeExpenseRow>,
          ),
          HomeExpenseRow,
          PrefetchHooks Function()
        > {
  $$HomeExpensesTableTableManager(_$AppDatabase db, $HomeExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HomeExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HomeExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HomeExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> amountMinorUnits = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> expenseDateEpochMillis = const Value.absent(),
                Value<int> dueYear = const Value.absent(),
                Value<int> dueMonth = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HomeExpensesCompanion(
                id: id,
                amountMinorUnits: amountMinorUnits,
                categoryId: categoryId,
                expenseDateEpochMillis: expenseDateEpochMillis,
                dueYear: dueYear,
                dueMonth: dueMonth,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int amountMinorUnits,
                required String categoryId,
                required int expenseDateEpochMillis,
                required int dueYear,
                required int dueMonth,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HomeExpensesCompanion.insert(
                id: id,
                amountMinorUnits: amountMinorUnits,
                categoryId: categoryId,
                expenseDateEpochMillis: expenseDateEpochMillis,
                dueYear: dueYear,
                dueMonth: dueMonth,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HomeExpensesTable, HomeExpenseRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $HomeExpensesTable,
                    HomeExpenseRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HomeExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HomeExpensesTable,
      HomeExpenseRow,
      $$HomeExpensesTableFilterComposer,
      $$HomeExpensesTableOrderingComposer,
      $$HomeExpensesTableAnnotationComposer,
      $$HomeExpensesTableCreateCompanionBuilder,
      $$HomeExpensesTableUpdateCompanionBuilder,
      (
        HomeExpenseRow,
        BaseReferences<_$AppDatabase, $HomeExpensesTable, HomeExpenseRow>,
      ),
      HomeExpenseRow,
      PrefetchHooks Function()
    >;
typedef $$WorkEntriesTableCreateCompanionBuilder =
    WorkEntriesCompanion Function({
      required String id,
      required String kind,
      required int amountMinorUnits,
      required int dueYear,
      required int dueMonth,
      required int recordedAtEpochMillis,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$WorkEntriesTableUpdateCompanionBuilder =
    WorkEntriesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<int> amountMinorUnits,
      Value<int> dueYear,
      Value<int> dueMonth,
      Value<int> recordedAtEpochMillis,
      Value<String?> note,
      Value<int> rowid,
    });

class $$WorkEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkEntriesTable> {
  $$WorkEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueYear => $composableBuilder(
    column: $table.dueYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueMonth => $composableBuilder(
    column: $table.dueMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedAtEpochMillis => $composableBuilder(
    column: $table.recordedAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkEntriesTable> {
  $$WorkEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueYear => $composableBuilder(
    column: $table.dueYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueMonth => $composableBuilder(
    column: $table.dueMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedAtEpochMillis => $composableBuilder(
    column: $table.recordedAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkEntriesTable> {
  $$WorkEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueYear =>
      $composableBuilder(column: $table.dueYear, builder: (column) => column);

  GeneratedColumn<int> get dueMonth =>
      $composableBuilder(column: $table.dueMonth, builder: (column) => column);

  GeneratedColumn<int> get recordedAtEpochMillis => $composableBuilder(
    column: $table.recordedAtEpochMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$WorkEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkEntriesTable,
          WorkEntryRow,
          $$WorkEntriesTableFilterComposer,
          $$WorkEntriesTableOrderingComposer,
          $$WorkEntriesTableAnnotationComposer,
          $$WorkEntriesTableCreateCompanionBuilder,
          $$WorkEntriesTableUpdateCompanionBuilder,
          (
            WorkEntryRow,
            BaseReferences<_$AppDatabase, $WorkEntriesTable, WorkEntryRow>,
          ),
          WorkEntryRow,
          PrefetchHooks Function()
        > {
  $$WorkEntriesTableTableManager(_$AppDatabase db, $WorkEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> amountMinorUnits = const Value.absent(),
                Value<int> dueYear = const Value.absent(),
                Value<int> dueMonth = const Value.absent(),
                Value<int> recordedAtEpochMillis = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkEntriesCompanion(
                id: id,
                kind: kind,
                amountMinorUnits: amountMinorUnits,
                dueYear: dueYear,
                dueMonth: dueMonth,
                recordedAtEpochMillis: recordedAtEpochMillis,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required int amountMinorUnits,
                required int dueYear,
                required int dueMonth,
                required int recordedAtEpochMillis,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkEntriesCompanion.insert(
                id: id,
                kind: kind,
                amountMinorUnits: amountMinorUnits,
                dueYear: dueYear,
                dueMonth: dueMonth,
                recordedAtEpochMillis: recordedAtEpochMillis,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkEntriesTable, WorkEntryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkEntriesTable,
                    WorkEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkEntriesTable,
      WorkEntryRow,
      $$WorkEntriesTableFilterComposer,
      $$WorkEntriesTableOrderingComposer,
      $$WorkEntriesTableAnnotationComposer,
      $$WorkEntriesTableCreateCompanionBuilder,
      $$WorkEntriesTableUpdateCompanionBuilder,
      (
        WorkEntryRow,
        BaseReferences<_$AppDatabase, $WorkEntriesTable, WorkEntryRow>,
      ),
      WorkEntryRow,
      PrefetchHooks Function()
    >;
typedef $$WorkHomeTransfersTableCreateCompanionBuilder =
    WorkHomeTransfersCompanion Function({
      required String id,
      required int amountMinorUnits,
      required int transferredAtEpochMillis,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$WorkHomeTransfersTableUpdateCompanionBuilder =
    WorkHomeTransfersCompanion Function({
      Value<String> id,
      Value<int> amountMinorUnits,
      Value<int> transferredAtEpochMillis,
      Value<String?> note,
      Value<int> rowid,
    });

class $$WorkHomeTransfersTableFilterComposer
    extends Composer<_$AppDatabase, $WorkHomeTransfersTable> {
  $$WorkHomeTransfersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transferredAtEpochMillis => $composableBuilder(
    column: $table.transferredAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkHomeTransfersTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkHomeTransfersTable> {
  $$WorkHomeTransfersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transferredAtEpochMillis => $composableBuilder(
    column: $table.transferredAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkHomeTransfersTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkHomeTransfersTable> {
  $$WorkHomeTransfersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transferredAtEpochMillis => $composableBuilder(
    column: $table.transferredAtEpochMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$WorkHomeTransfersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkHomeTransfersTable,
          WorkHomeTransferRow,
          $$WorkHomeTransfersTableFilterComposer,
          $$WorkHomeTransfersTableOrderingComposer,
          $$WorkHomeTransfersTableAnnotationComposer,
          $$WorkHomeTransfersTableCreateCompanionBuilder,
          $$WorkHomeTransfersTableUpdateCompanionBuilder,
          (
            WorkHomeTransferRow,
            BaseReferences<
              _$AppDatabase,
              $WorkHomeTransfersTable,
              WorkHomeTransferRow
            >,
          ),
          WorkHomeTransferRow,
          PrefetchHooks Function()
        > {
  $$WorkHomeTransfersTableTableManager(
    _$AppDatabase db,
    $WorkHomeTransfersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkHomeTransfersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkHomeTransfersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkHomeTransfersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> amountMinorUnits = const Value.absent(),
                Value<int> transferredAtEpochMillis = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkHomeTransfersCompanion(
                id: id,
                amountMinorUnits: amountMinorUnits,
                transferredAtEpochMillis: transferredAtEpochMillis,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int amountMinorUnits,
                required int transferredAtEpochMillis,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkHomeTransfersCompanion.insert(
                id: id,
                amountMinorUnits: amountMinorUnits,
                transferredAtEpochMillis: transferredAtEpochMillis,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkHomeTransfersTable, WorkHomeTransferRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $WorkHomeTransfersTable,
                    WorkHomeTransferRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkHomeTransfersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkHomeTransfersTable,
      WorkHomeTransferRow,
      $$WorkHomeTransfersTableFilterComposer,
      $$WorkHomeTransfersTableOrderingComposer,
      $$WorkHomeTransfersTableAnnotationComposer,
      $$WorkHomeTransfersTableCreateCompanionBuilder,
      $$WorkHomeTransfersTableUpdateCompanionBuilder,
      (
        WorkHomeTransferRow,
        BaseReferences<
          _$AppDatabase,
          $WorkHomeTransfersTable,
          WorkHomeTransferRow
        >,
      ),
      WorkHomeTransferRow,
      PrefetchHooks Function()
    >;
typedef $$DebtsTableCreateCompanionBuilder = DebtsCompanion Function({
  required String id,
  required String direction,
  required int originalAmountMinorUnits,
  required int outstandingAmountMinorUnits,
  required int dueYear,
  required int dueMonth,
  required int createdAtEpochMillis,
  required String counterparty,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$DebtsTableUpdateCompanionBuilder = DebtsCompanion Function({
  Value<String> id,
  Value<String> direction,
  Value<int> originalAmountMinorUnits,
  Value<int> outstandingAmountMinorUnits,
  Value<int> dueYear,
  Value<int> dueMonth,
  Value<int> createdAtEpochMillis,
  Value<String> counterparty,
  Value<String?> note,
  Value<int> rowid,
});

class $$DebtsTableFilterComposer extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalAmountMinorUnits => $composableBuilder(
    column: $table.originalAmountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outstandingAmountMinorUnits => $composableBuilder(
    column: $table.outstandingAmountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueYear => $composableBuilder(
    column: $table.dueYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueMonth => $composableBuilder(
    column: $table.dueMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DebtsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalAmountMinorUnits => $composableBuilder(
    column: $table.originalAmountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outstandingAmountMinorUnits => $composableBuilder(
    column: $table.outstandingAmountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueYear => $composableBuilder(
    column: $table.dueYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueMonth => $composableBuilder(
    column: $table.dueMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get originalAmountMinorUnits => $composableBuilder(
    column: $table.originalAmountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outstandingAmountMinorUnits => $composableBuilder(
    column: $table.outstandingAmountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueYear =>
      $composableBuilder(column: $table.dueYear, builder: (column) => column);

  GeneratedColumn<int> get dueMonth =>
      $composableBuilder(column: $table.dueMonth, builder: (column) => column);

  GeneratedColumn<int> get createdAtEpochMillis => $composableBuilder(
    column: $table.createdAtEpochMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$DebtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebtsTable,
          DebtRow,
          $$DebtsTableFilterComposer,
          $$DebtsTableOrderingComposer,
          $$DebtsTableAnnotationComposer,
          $$DebtsTableCreateCompanionBuilder,
          $$DebtsTableUpdateCompanionBuilder,
          (DebtRow, BaseReferences<_$AppDatabase, $DebtsTable, DebtRow>),
          DebtRow,
          PrefetchHooks Function()
        > {
  $$DebtsTableTableManager(_$AppDatabase db, $DebtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<int> originalAmountMinorUnits = const Value.absent(),
                Value<int> outstandingAmountMinorUnits = const Value.absent(),
                Value<int> dueYear = const Value.absent(),
                Value<int> dueMonth = const Value.absent(),
                Value<int> createdAtEpochMillis = const Value.absent(),
                Value<String> counterparty = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion(
                id: id,
                direction: direction,
                originalAmountMinorUnits: originalAmountMinorUnits,
                outstandingAmountMinorUnits: outstandingAmountMinorUnits,
                dueYear: dueYear,
                dueMonth: dueMonth,
                createdAtEpochMillis: createdAtEpochMillis,
                counterparty: counterparty,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String direction,
                required int originalAmountMinorUnits,
                required int outstandingAmountMinorUnits,
                required int dueYear,
                required int dueMonth,
                required int createdAtEpochMillis,
                required String counterparty,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion.insert(
                id: id,
                direction: direction,
                originalAmountMinorUnits: originalAmountMinorUnits,
                outstandingAmountMinorUnits: outstandingAmountMinorUnits,
                dueYear: dueYear,
                dueMonth: dueMonth,
                createdAtEpochMillis: createdAtEpochMillis,
                counterparty: counterparty,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DebtsTable, DebtRow>(table),
                  BaseReferences<_$AppDatabase, $DebtsTable, DebtRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DebtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebtsTable,
      DebtRow,
      $$DebtsTableFilterComposer,
      $$DebtsTableOrderingComposer,
      $$DebtsTableAnnotationComposer,
      $$DebtsTableCreateCompanionBuilder,
      $$DebtsTableUpdateCompanionBuilder,
      (DebtRow, BaseReferences<_$AppDatabase, $DebtsTable, DebtRow>),
      DebtRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HomeExpensesTableTableManager get homeExpenses =>
      $$HomeExpensesTableTableManager(_db, _db.homeExpenses);
  $$WorkEntriesTableTableManager get workEntries =>
      $$WorkEntriesTableTableManager(_db, _db.workEntries);
  $$WorkHomeTransfersTableTableManager get workHomeTransfers =>
      $$WorkHomeTransfersTableTableManager(_db, _db.workHomeTransfers);
  $$DebtsTableTableManager get debts =>
      $$DebtsTableTableManager(_db, _db.debts);
}
