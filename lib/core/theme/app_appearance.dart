import 'package:material_ui/material_ui.dart';

/// A portable theme recipe. The palette is rendered with native Flutter
/// ColorScheme values; the HTML studio is not embedded in the Android app.
class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.hue,
    required this.accentHue,
    required this.chroma,
    required this.accentChroma,
    required this.hueOffset,
    required this.background,
    this.effects = '',
    this.custom = false,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final double hue;
  final double accentHue;
  final double chroma;
  final double accentChroma;
  final double hueOffset;
  final String background;
  final String effects;
  final bool custom;

  Color get seedColor => HSLColor.fromAHSL(
        1,
        hue % 360,
        (chroma * 4).clamp(.08, .88).toDouble(),
        .54,
      ).toColor();

  Color get accentSeedColor => HSLColor.fromAHSL(
        1,
        accentHue % 360,
        (accentChroma * 4).clamp(.08, .88).toDouble(),
        .58,
      ).toColor();

  factory AppThemePreset.fromSeedColor(
    Color color, {
    required String id,
    required String nameAr,
    required String nameEn,
    String background = 'fluid',
  }) {
    final hsl = HSLColor.fromColor(color);
    final chroma = (hsl.saturation / 4).clamp(.07, .22).toDouble();
    return AppThemePreset(
      id: id,
      nameAr: nameAr,
      nameEn: nameEn,
      hue: hsl.hue,
      accentHue: (hsl.hue + 25) % 360,
      chroma: chroma,
      accentChroma: chroma,
      hueOffset: 70,
      background: background,
      effects: 'v',
      custom: true,
    );
  }

  AppThemePreset copyWith({String? nameAr, String? nameEn}) {
    return AppThemePreset(
      id: id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      hue: hue,
      accentHue: accentHue,
      chroma: chroma,
      accentChroma: accentChroma,
      hueOffset: hueOffset,
      background: background,
      effects: effects,
      custom: custom,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'hue': hue,
        'accentHue': accentHue,
        'chroma': chroma,
        'accentChroma': accentChroma,
        'hueOffset': hueOffset,
        'background': background,
        'effects': effects,
        'custom': custom,
      };

  factory AppThemePreset.fromJson(Map<String, Object?> json) {
    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    return AppThemePreset(
      id: json['id'] is String ? json['id']! as String : 'custom-imported',
      nameAr:
          json['nameAr'] is String ? json['nameAr']! as String : 'ثيمي',
      nameEn: json['nameEn'] is String
          ? json['nameEn']! as String
          : 'My theme',
      hue: number('hue', 330),
      accentHue: number('accentHue', 350),
      chroma: number('chroma', .16).clamp(.01, .3).toDouble(),
      accentChroma: number('accentChroma', .16).clamp(.01, .3).toDouble(),
      hueOffset: number('hueOffset', 70),
      background: json['background'] is String
          ? json['background']! as String
          : 'aurora',
      effects:
          json['effects'] is String ? json['effects']! as String : '',
      custom: json['custom'] == true,
    );
  }
}

AppThemePreset _theme(
  String id,
  String ar,
  String en,
  double hue,
  double accentHue,
  double chroma,
  double accentChroma,
  double offset,
  String background, [
  String effects = '',
]) =>
    AppThemePreset(
      id: id,
      nameAr: ar,
      nameEn: en,
      hue: hue,
      accentHue: accentHue,
      chroma: chroma,
      accentChroma: accentChroma,
      hueOffset: offset,
      background: background,
      effects: effects,
    );

/// The 77 built-in palettes supplied by the user's theme studio.
final List<AppThemePreset> builtInThemePresets = [
  _theme('purple-pro', 'بنفسجي برو', 'Purple Pro', 330, 350, .16, .16, 70, 'aurora'),
  _theme('copper', 'نحاسي', 'Copper', 75, 85, .12, .14, 60, 'particles'),
  _theme('cyan-magenta', 'سيان وأرجواني', 'Cyan & Magenta', 290, 200, .15, .15, 100, 'stars'),
  _theme('emerald', 'زمردي', 'Emerald', 160, 165, .13, .13, 60, 'flow'),
  _theme('ruby', 'ياقوتي', 'Ruby', 20, 12, .18, .18, 60, 'aurora'),
  _theme('ocean', 'محيطي', 'Ocean', 235, 225, .14, .14, 50, 'flow'),
  _theme('sunset', 'غروب', 'Sunset', 40, 18, .17, .17, 60, 'leaks'),
  _theme('sand', 'رملي', 'Sand', 85, 62, .07, .10, 50, 'none'),
  _theme('lavender', 'لافندر', 'Lavender', 275, 300, .12, .12, 60, 'particles'),
  _theme('noir', 'نوار', 'Noir', 260, 75, .02, .15, 0, 'leaks', 'lgv'),
  _theme('teal-orange', 'تيل وبرتقالي', 'Teal & Orange', 215, 55, .09, .17, 160, 'aurora', 'lv'),
  _theme('cyber', 'سايبر', 'Cyber', 300, 345, .22, .22, -135, 'grid', 'gv'),
  _theme('35mm-film', 'فيلم ٣٥ ملم', '35mm Film', 60, 48, .06, .10, 40, 'leaks', 'gv'),
  _theme('green-code', 'شيفرة خضراء', 'Green Code', 150, 150, .20, .20, 0, 'code', 'v'),
  _theme('aurora', 'شفق قطبي', 'Aurora', 270, 170, .15, .15, 60, 'aurora', 'v'),
  _theme('lemon', 'ليموني', 'Lemon', 112, 125, .15, .15, 60, 'particles'),
  _theme('mint', 'نعناعي', 'Mint', 170, 150, .12, .12, 60, 'flow'),
  _theme('turquoise', 'فيروزي', 'Turquoise', 195, 185, .13, .13, 50, 'aurora'),
  _theme('sky', 'سماوي', 'Sky', 225, 245, .13, .13, 50, 'stars'),
  _theme('cobalt', 'كوبالت', 'Cobalt', 255, 265, .17, .17, 60, 'plasma'),
  _theme('indigo', 'نيلي', 'Indigo', 270, 285, .18, .18, 60, 'smoke'),
  _theme('royal-violet', 'بنفسج ملكي', 'Royal Violet', 295, 310, .19, .19, 60, 'aurora'),
  _theme('purple', 'أرجواني', 'Purple', 320, 335, .20, .20, 60, 'fluid'),
  _theme('pink', 'وردي', 'Pink', 350, 5, .17, .17, 60, 'particles'),
  _theme('cherry', 'كرزي', 'Cherry', 10, 25, .20, .20, 60, 'smoke'),
  _theme('coral', 'مرجاني', 'Coral', 25, 40, .16, .16, 50, 'leaks'),
  _theme('orange', 'برتقالي', 'Orange', 50, 65, .18, .18, 60, 'flow'),
  _theme('amber', 'عنبري', 'Amber', 70, 85, .16, .16, 50, 'leaks'),
  _theme('gold', 'ذهبي', 'Gold', 90, 100, .15, .15, 40, 'particles'),
  _theme('olive', 'زيتوني', 'Olive', 115, 130, .10, .10, 50, 'none'),
  _theme('forest', 'غابة', 'Forest', 145, 160, .10, .10, 50, 'aurora'),
  _theme('moss', 'طحلبي', 'Moss', 135, 120, .12, .12, 50, 'flow'),
  _theme('dark-green', 'أخضر ليلي', 'Night Green', 155, 180, .14, .14, 50, 'stars'),
  _theme('icy', 'جليدي', 'Icy', 215, 230, .05, .08, 40, 'aurora'),
  _theme('snow', 'ثلجي', 'Snow', 240, 260, .03, .06, 40, 'none'),
  _theme('metallic', 'معدني', 'Metallic', 250, 250, .02, .05, 0, 'particles'),
  _theme('charcoal', 'فحمي', 'Charcoal', 40, 40, .01, .08, 0, 'none'),
  _theme('coffee', 'قهوة', 'Coffee', 55, 45, .06, .09, 30, 'leaks'),
  _theme('chocolate', 'شوكولاتة', 'Chocolate', 40, 30, .08, .10, 30, 'smoke'),
  _theme('peach', 'خوخي', 'Peach', 40, 50, .10, .10, 50, 'flow'),
  _theme('lilac', 'ليلكي', 'Lilac', 300, 320, .10, .10, 60, 'aurora'),
  _theme('grape', 'عنبي', 'Grape', 320, 300, .15, .15, 60, 'plasma'),
  _theme('berry', 'توتي', 'Berry', 345, 330, .18, .18, 60, 'fluid'),
  _theme('ember', 'جمري', 'Ember', 30, 15, .19, .19, 50, 'smoke'),
  _theme('desert', 'صحراوي', 'Desert', 70, 50, .08, .12, 40, 'none'),
  _theme('oasis', 'واحة', 'Oasis', 150, 100, .11, .12, 60, 'flow'),
  _theme('crystal', 'كريستال', 'Crystal', 210, 300, .10, .10, 90, 'stars'),
  _theme('candy', 'حلوى', 'Candy', 350, 200, .16, .16, 100, 'fluid'),
  _theme('western', 'ويسترن', 'Western', 45, 40, .09, .14, 40, 'leaks', 'gv'),
  _theme('golden-epic', 'ملحمة ذهبية', 'Golden Epic', 80, 85, .07, .15, 30, 'leaks', 'lgv'),
  _theme('sci-fi', 'خيال علمي', 'Sci-Fi', 220, 200, .10, .15, 60, 'stars', 'lv'),
  _theme('deep-space', 'فضاء عميق', 'Deep Space', 265, 230, .12, .14, 50, 'stars', 'lv'),
  _theme('horror', 'رعب', 'Horror', 10, 15, .10, .17, 40, 'smoke', 'gv'),
  _theme('cold-thriller', 'إثارة باردة', 'Cold Thriller', 230, 215, .05, .10, 30, 'smoke', 'lgv'),
  _theme('romance', 'رومانسية', 'Romance', 355, 15, .12, .14, 40, 'leaks', 'gv'),
  _theme('seventies', 'السبعينات', 'Seventies', 60, 35, .08, .13, 40, 'leaks', 'gv'),
  _theme('neon-crime', 'جريمة نيون', 'Neon Crime', 330, 190, .18, .18, 40, 'grid', 'lgv'),
  _theme('silent-drama', 'دراما صامتة', 'Silent Drama', 250, 260, .03, .06, 30, 'none', 'lv'),
  _theme('city-rain', 'مطر المدينة', 'City Rain', 230, 40, .06, .14, 150, 'smoke', 'lv'),
  _theme('silent-film', 'فيلم صامت', 'Silent Film', 0, 0, 0, 0, 0, 'particles', 'lgv'),
  _theme('war', 'حرب', 'War', 100, 70, .05, .10, 30, 'smoke', 'lgv'),
  _theme('desert-journey', 'رحلة صحراوية', 'Desert Journey', 65, 50, .10, .15, 40, 'leaks', 'lv'),
  _theme('enchanted-forest', 'غابة مسحورة', 'Enchanted Forest', 150, 300, .12, .14, 60, 'aurora', 'v'),
  _theme('deep-sea', 'أعماق البحر', 'Deep Sea', 215, 185, .10, .13, 40, 'flow', 'v'),
  _theme('volcano', 'بركان', 'Volcano', 25, 45, .16, .19, 30, 'smoke', 'gv'),
  _theme('polar-ice', 'جليد قطبي', 'Polar Ice', 220, 200, .05, .10, 30, 'aurora', 'v'),
  _theme('night-race', 'سباق ليلي', 'Night Race', 285, 40, .14, .20, 120, 'grid', 'lv'),
  _theme('casino', 'كازينو', 'Casino', 150, 85, .10, .13, 60, 'leaks', 'gv'),
  _theme('theater', 'مسرح', 'Theater', 350, 80, .14, .15, 50, 'leaks', 'lv'),
  _theme('three-dimensional', 'ثلاثي الأبعاد', 'Three Dimensional', 280, 170, .15, .17, 60, 'plasma', 'lv'),
  _theme('dusk', 'غسق', 'Dusk', 15, 300, .12, .16, 70, 'fluid', 'lv'),
  _theme('golden-dawn', 'فجر ذهبي', 'Golden Dawn', 50, 25, .10, .16, 40, 'aurora', 'v'),
  _theme('london-fog', 'ضباب لندني', 'London Fog', 230, 230, .02, .05, 0, 'smoke', 'gv'),
  _theme('calm-lake', 'بحيرة هادئة', 'Calm Lake', 200, 170, .06, .10, 40, 'flow', 'v'),
  _theme('hot-action', 'أكشن حارق', 'Hot Action', 20, 50, .17, .20, 60, 'plasma', 'lgv'),
  _theme('golden-code', 'شيفرة ذهبية', 'Golden Code', 85, 85, .15, .15, 0, 'code', 'v'),
  _theme('neon-80', 'نيون ٨٠', 'Neon 80', 310, 200, .20, .22, 100, 'grid', 'gv'),
];

AppThemePreset themePresetById(
  String? id, {
  List<AppThemePreset> customThemes = const [],
}) {
  for (final theme in customThemes) {
    if (theme.id == id) return theme;
  }
  for (final theme in builtInThemePresets) {
    if (theme.id == id) return theme;
  }
  // Upgrade older saved theme identifiers to the closest new palette.
  return switch (id) {
    'navy_gold' => builtInThemePresets.firstWhere((e) => e.id == 'cobalt'),
    'graphite' => builtInThemePresets.firstWhere((e) => e.id == 'charcoal'),
    _ => builtInThemePresets.first,
  };
}

class ThemeBackgroundOption {
  const ThemeBackgroundOption(this.id, this.nameAr, this.nameEn);
  final String id;
  final String nameAr;
  final String nameEn;
}

const themeBackgrounds = <ThemeBackgroundOption>[
  ThemeBackgroundOption('fluid', 'سائل WebGL', 'Fluid'),
  ThemeBackgroundOption('plasma', 'بلازما WebGL', 'Plasma'),
  ThemeBackgroundOption('smoke', 'دخان WebGL', 'Smoke'),
  ThemeBackgroundOption('aurora', 'شفق', 'Aurora'),
  ThemeBackgroundOption('leaks', 'تسريب ضوئي', 'Light Leaks'),
  ThemeBackgroundOption('flow', 'أمواج', 'Waves'),
  ThemeBackgroundOption('particles', 'جزيئات', 'Particles'),
  ThemeBackgroundOption('stars', 'نجوم', 'Stars'),
  ThemeBackgroundOption('grid', 'شبكة نيون', 'Neon Grid'),
  ThemeBackgroundOption('code', 'شيفرة', 'Code'),
  ThemeBackgroundOption('none', 'بدون', 'None'),
];

const themeGrades = <String, String>{
  '': 'بدون',
  'warm': 'دافئ',
  'cool': 'بارد',
  'bleach': 'مبيّض',
  'mono': 'أبيض وأسود',
};
