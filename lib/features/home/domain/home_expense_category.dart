class HomeExpenseCategory {
  const HomeExpenseCategory({required this.id, this.name = ''});

  final String id;
  final String name;

  HomeExpenseCategory copyWith({String? name}) =>
      HomeExpenseCategory(id: id, name: name ?? this.name);

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory HomeExpenseCategory.fromJson(Map<String, dynamic> json) =>
      HomeExpenseCategory(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
      );

  static const defaults = <HomeExpenseCategory>[
    HomeExpenseCategory(id: 'groceries'),
    HomeExpenseCategory(id: 'utilities'),
    HomeExpenseCategory(id: 'housing'),
    HomeExpenseCategory(id: 'cleaning'),
    HomeExpenseCategory(id: 'maintenance'),
    HomeExpenseCategory(id: 'transport'),
    HomeExpenseCategory(id: 'personal'),
    HomeExpenseCategory(id: 'health'),
    HomeExpenseCategory(id: 'other'),
  ];
}
