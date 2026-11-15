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

  String label({required bool isArabic}) {
    return switch (this) {
      AppThemePreset.navyGold => isArabic ? 'كحلي وذهبي' : 'Navy & Gold',
      AppThemePreset.emerald => isArabic ? 'زمردي' : 'Emerald',
      AppThemePreset.graphite => isArabic ? 'فحمي' : 'Graphite',
    };
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

  String label({required bool isArabic}) {
    return switch (this) {
      AppDensity.comfortable =>
        isArabic ? 'مريح' : 'Comfortable',
      AppDensity.compact => isArabic ? 'مضغوط' : 'Compact',
    };
  }
}
