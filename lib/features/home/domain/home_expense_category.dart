class HomeExpenseCategory {
  const HomeExpenseCategory({
    required this.id,
    this.name = '',
    this.iconKey = 'category',
  });

  final String id;
  final String name;
  final String iconKey;

  HomeExpenseCategory copyWith({String? name, String? iconKey}) =>
      HomeExpenseCategory(
        id: id,
        name: name ?? this.name,
        iconKey: iconKey ?? this.iconKey,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
      };

  factory HomeExpenseCategory.fromJson(Map<String, dynamic> json) =>
      HomeExpenseCategory(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        // Older saved custom categories did not store an icon. Keep them
        // readable and assign a standard category icon without data loss.
        iconKey: (json['iconKey'] as String?) ?? 'category',
      );

  static const defaults = <HomeExpenseCategory>[
    HomeExpenseCategory(id: 'groceries', iconKey: 'groceries'),
    HomeExpenseCategory(id: 'utilities', iconKey: 'utilities'),
    HomeExpenseCategory(id: 'housing', iconKey: 'housing'),
    HomeExpenseCategory(id: 'cleaning', iconKey: 'cleaning'),
    HomeExpenseCategory(id: 'maintenance', iconKey: 'maintenance'),
    HomeExpenseCategory(id: 'transport', iconKey: 'transport'),
    HomeExpenseCategory(id: 'personal', iconKey: 'personal'),
    HomeExpenseCategory(id: 'health', iconKey: 'health'),
    HomeExpenseCategory(id: 'education', iconKey: 'education'),
    HomeExpenseCategory(id: 'communications', iconKey: 'communications'),
    HomeExpenseCategory(id: 'entertainment', iconKey: 'entertainment'),
    HomeExpenseCategory(id: 'clothing', iconKey: 'clothing'),
    HomeExpenseCategory(id: 'gifts', iconKey: 'gifts'),
    HomeExpenseCategory(id: 'other', iconKey: 'other'),
  ];
}
