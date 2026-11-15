enum AppThemePreset {
  navyGold('navy_gold'),
  emerald('emerald'),
  graphite('graphite');

  const AppThemePreset(this.storageKey);

  final String storageKey;

  static AppThemePreset fromStorage(String? value) {
    return AppThemePreset.values.firstWhere(
      (preset) => preset.storageKey == value,
      orElse: () => AppThemePreset.navyGold,
    );
  }
}

enum AppDensity {
  comfortable('comfortable'),
  compact('compact');

  const AppDensity(this.storageKey);

  final String storageKey;

  static AppDensity fromStorage(String? value) {
    return AppDensity.values.firstWhere(
      (density) => density.storageKey == value,
      orElse: () => AppDensity.comfortable,
    );
  }
}
