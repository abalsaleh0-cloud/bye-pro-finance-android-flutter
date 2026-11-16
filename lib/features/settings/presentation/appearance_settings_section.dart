import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

class AppearanceSettingsSection extends ConsumerStatefulWidget {
  const AppearanceSettingsSection({super.key});

  @override
  ConsumerState<AppearanceSettingsSection> createState() =>
      _AppearanceSettingsSectionState();
}

class _AppearanceSettingsSectionState
    extends ConsumerState<AppearanceSettingsSection> {
  static const _seedColors = <Color>[
    Color(0xFF9C27B0), Color(0xFF673AB7), Color(0xFF3F51B5),
    Color(0xFF2196F3), Color(0xFF00ACC1), Color(0xFF009688),
    Color(0xFF2E7D32), Color(0xFF8BC34A), Color(0xFFC0A000),
    Color(0xFFFF9800), Color(0xFFF4511E), Color(0xFFE53935),
    Color(0xFFEC407A), Color(0xFF795548), Color(0xFF607D8B),
    Color(0xFF455A64), Color(0xFFB0BEC5), Color(0xFFD7CCC8),
  ];

  String _searchQuery = '';

  String _text(BuildContext context, String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : ar;

  Future<void> _createFromColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => _SeedColorPickerDialog(seedColors: _seedColors),
    );
    if (color == null || !mounted) {
      return;
    }
    _saveCustomTheme(color);
  }

  Future<void> _createFromImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 320,
        maxHeight: 320,
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 48,
        targetHeight: 48,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      codec.dispose();
      if (data == null) {
        throw StateError('Image pixels unavailable');
      }

      final pixels = data.buffer.asUint8List();
      final bins = List.generate(12, (_) => List<double>.filled(4, 0));
      for (var i = 0; i + 3 < pixels.length; i += 4) {
        final color = Color.fromARGB(
          pixels[i + 3],
          pixels[i],
          pixels[i + 1],
          pixels[i + 2],
        );
        final hsl = HSLColor.fromColor(color);
        if (hsl.lightness < .16 ||
            hsl.lightness > .94 ||
            hsl.saturation < .08) {
          continue;
        }
        final index = (hsl.hue / 30).floor().clamp(0, 11).toInt();
        final weight = hsl.saturation;
        final bin = bins[index];
        bin[0] += weight;
        bin[1] += pixels[i] * weight;
        bin[2] += pixels[i + 1] * weight;
        bin[3] += pixels[i + 2] * weight;
      }

      bins.sort((a, b) => b[0].compareTo(a[0]));
      final strongest = bins.first;
      if (strongest[0] <= 0) {
        throw StateError('No usable colors found in the image');
      }
      final color = Color.fromARGB(
        255,
        (strongest[1] / strongest[0]).round().clamp(0, 255).toInt(),
        (strongest[2] / strongest[0]).round().clamp(0, 255).toInt(),
        (strongest[3] / strongest[0]).round().clamp(0, 255).toInt(),
      );
      if (!mounted) {
        return;
      }
      _saveCustomTheme(color);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              context,
              'تعذر استخراج الألوان من الصورة.',
              'Could not extract colors from the image.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _exportThemeJson() async {
    final theme = ref.read(appSettingsProvider).selectedTheme;
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(theme.toJson())));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_text(context, 'تم نسخ بيانات الثيم.', 'Theme JSON copied.'))),
    );
  }

  Future<void> _exportFlutterTheme() async {
    final theme = ref.read(appSettingsProvider).selectedTheme;
    final light = AppTheme.colorSchemeFor(theme, brightness: Brightness.light);
    final dark = AppTheme.colorSchemeFor(theme, brightness: Brightness.dark);
    String hex(Color color) => '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final source = '''// ${theme.nameEn}
const lightPrimary = Color(${hex(light.primary)});
const lightSurface = Color(${hex(light.surface)});
const lightOnSurface = Color(${hex(light.onSurface)});
const darkPrimary = Color(${hex(dark.primary)});
const darkSurface = Color(${hex(dark.surface)});
const darkOnSurface = Color(${hex(dark.onSurface)});
''';
    await Clipboard.setData(ClipboardData(text: source));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_text(context, 'تم نسخ ألوان Flutter.', 'Flutter colors copied.'))),
    );
  }

  Future<void> _importThemeJson() async {
    final input = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text(context, 'استيراد ثيم JSON', 'Import theme JSON')),
        content: TextField(
          controller: input,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: _text(context, 'الصق بيانات الثيم هنا', 'Paste theme JSON here'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_text(context, 'إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input.text),
            child: Text(_text(context, 'استيراد', 'Import')),
          ),
        ],
      ),
    );
    input.dispose();
    if (raw == null || raw.trim().isEmpty || !mounted) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Theme JSON must be an object');
      }
      final map = Map<String, Object?>.from(decoded);
      final imported = AppThemePreset.fromJson(map).copyWith(
        nameAr: map['nameAr'] is String ? map['nameAr']! as String : 'ثيم مستورد',
        nameEn: map['nameEn'] is String ? map['nameEn']! as String : 'Imported theme',
      );
      final settings = ref.read(appSettingsProvider);
      if (settings.customThemes.length >= 12 &&
          !settings.customThemes.any((theme) => theme.id == imported.id)) {
        throw StateError('Custom theme limit reached');
      }
      ref.read(appSettingsProvider.notifier).addCustomTheme(imported);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(context, 'تم استيراد الثيم.', 'Theme imported.'))),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(context, 'بيانات JSON غير صالحة.', 'Invalid theme JSON.'))),
      );
    }
  }

  void _saveCurrentTheme() {
    final settings = ref.read(appSettingsProvider);
    if (settings.customThemes.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              context,
              'وصلت إلى الحد الأقصى للثيمات الخاصة.',
              'You reached the custom theme limit.',
            ),
          ),
        ),
      );
      return;
    }
    final source = settings.selectedTheme;
    final index = settings.customThemes.length + 1;
    final copy = AppThemePreset(
      id: 'custom-copy-${DateTime.now().microsecondsSinceEpoch}',
      nameAr: 'نسخة $index',
      nameEn: 'Theme copy $index',
      hue: source.hue,
      accentHue: source.accentHue,
      chroma: source.chroma,
      accentChroma: source.accentChroma,
      hueOffset: source.hueOffset,
      background: source.background,
      effects: source.effects,
      custom: true,
    );
    ref.read(appSettingsProvider.notifier).addCustomTheme(copy);
  }

  void _selectRandomTheme() {
    final index = math.Random().nextInt(builtInThemePresets.length);
    ref.read(appSettingsProvider.notifier).setTheme(builtInThemePresets[index]);
  }

  void _saveCustomTheme(Color color) {
    final settings = ref.read(appSettingsProvider);
    if (settings.customThemes.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              context,
              'يمكن حفظ 12 ثيمًا خاصًا كحد أقصى.',
              'You can save up to 12 custom themes.',
            ),
          ),
        ),
      );
      return;
    }
    final index = settings.customThemes.length + 1;
    final theme = AppThemePreset.fromSeedColor(
      color,
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      nameAr: 'ثيمي $index',
      nameEn: 'My theme $index',
    );
    ref.read(appSettingsProvider.notifier).addCustomTheme(theme);
  }

  Widget _sectionTitle(BuildContext context, String ar, String en) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 10),
      child: Text(
        _text(context, ar, en),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _themeGrid(
    BuildContext context,
    List<AppThemePreset> themes,
    String selectedId, {
    bool custom = false,
  }) {
    if (themes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _text(context, 'لم تحفظ ثيمات خاصة بعد.', 'No custom themes saved.'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 5 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: themes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
            childAspectRatio: .92,
          ),
          itemBuilder: (context, index) {
            final theme = themes[index];
            final selected = selectedId == theme.id;
            final name = Localizations.localeOf(context).languageCode == 'en'
                ? theme.nameEn
                : theme.nameAr;
            final first = theme.seedColor;
            final second = theme.accentSeedColor;
            return InkWell(
              key: ValueKey('theme-${theme.id}'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => ref.read(appSettingsProvider.notifier).setTheme(theme),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: selected ? 2.2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              HSLColor.fromColor(first)
                                  .withLightness(.23)
                                  .toColor(),
                              first,
                              second,
                            ],
                          ),
                        ),
                        child: selected
                            ? const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                          ),
                    ),
                    if (custom)
                      SizedBox(
                        height: 22,
                        child: IconButton(
                          key: ValueKey('delete-${theme.id}'),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          tooltip: _text(context, 'حذف الثيم', 'Delete theme'),
                          onPressed: () => ref
                              .read(appSettingsProvider.notifier)
                              .removeCustomTheme(theme.id),
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _contrastReport(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textRatio =
        AppTheme.contrastRatio(scheme.onSurface, scheme.surface);
    final mutedRatio =
        AppTheme.contrastRatio(scheme.onSurfaceVariant, scheme.surface);
    final buttonRatio =
        AppTheme.contrastRatio(scheme.onPrimary, scheme.primary);
    String grade(double ratio) => ratio >= 7
        ? 'AAA'
        : ratio >= 4.5
            ? 'AA'
            : ratio >= 3
                ? _text(context, 'للعناوين', 'Large text')
                : _text(context, 'ضعيف', 'Low');
    Widget result(String label, double ratio) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(
                '${ratio.toStringAsFixed(1)} · ${grade(ratio)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        );
    return Row(
      children: [
        Expanded(child: result(_text(context, 'النص', 'Text'), textRatio)),
        const SizedBox(width: 6),
        Expanded(
          child: result(
            _text(context, 'النص الثانوي', 'Muted text'),
            mutedRatio,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: result(
            _text(context, 'الزر', 'Button'),
            buttonRatio,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final selectedId = settings.themeId;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final query = _searchQuery.trim().toLowerCase();
    bool matches(AppThemePreset theme) =>
        query.isEmpty ||
        theme.nameAr.toLowerCase().contains(query) ||
        theme.nameEn.toLowerCase().contains(query);
    final basicThemes = [
      ...builtInThemePresets.take(9),
      ...builtInThemePresets.skip(15).take(33),
    ].where(matches).toList();
    final cinemaThemes = [
      ...builtInThemePresets.skip(9).take(6),
      ...builtInThemePresets.skip(48),
    ].where(matches).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _text(context, 'وضع المظهر', 'Appearance mode'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                KeyedSubtree(
                  key: const Key('dark-mode-switch'),
                  child: SegmentedButton<ThemeMode>(
                  key: const Key('theme-mode-selector'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(_text(context, 'نهاري', 'Light')),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(_text(context, 'الوضع الداكن', 'Dark')),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(_text(context, 'تلقائي', 'Auto')),
                      icon: const Icon(Icons.brightness_auto_outlined),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (values) =>
                      controller.setThemeMode(values.first),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('theme-search'),
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: _text(context, 'ابحث عن ثيم بالاسم', 'Search themes by name'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                _sectionTitle(context, 'الثيمات الأساسية', 'Base themes'),
                _themeGrid(context, basicThemes, selectedId),
                _sectionTitle(context, 'استوديو سينمائي', 'Cinema studio'),
                _themeGrid(context, cinemaThemes, selectedId),
                _sectionTitle(context, 'ثيماتك الخاصة', 'Your custom themes'),
                _themeGrid(
                  context,
                  settings.customThemes,
                  selectedId,
                  custom: true,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('create-theme-from-color'),
                      onPressed: settings.customThemes.length >= 12
                          ? null
                          : _createFromColor,
                      icon: const Icon(Icons.palette_outlined),
                      label: Text(_text(context, 'من لون', 'From color')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('save-current-custom-theme'),
                      onPressed: settings.customThemes.length >= 12
                          ? null
                          : _saveCurrentTheme,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(_text(context, 'حفظ الثيم الحالي', 'Save current')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('random-theme'),
                      onPressed: _selectRandomTheme,
                      icon: const Icon(Icons.shuffle),
                      label: Text(_text(context, 'عشوائي', 'Random')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('create-theme-from-image'),
                      onPressed: settings.customThemes.length >= 12
                          ? null
                          : _createFromImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_text(context, 'من صورة', 'From image')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('export-theme-json'),
                      onPressed: _exportThemeJson,
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(_text(context, 'نسخ JSON', 'Copy JSON')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('import-theme-json'),
                      onPressed: _importThemeJson,
                      icon: const Icon(Icons.input_outlined),
                      label: Text(_text(context, 'استيراد JSON', 'Import JSON')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('export-theme-flutter'),
                      onPressed: _exportFlutterTheme,
                      icon: const Icon(Icons.code_outlined),
                      label: Text(_text(context, 'تصدير Flutter', 'Export Flutter')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _text(
                    context,
                    'يمكنك حفظ حتى 12 ثيمًا خاصًا.',
                    'Up to 12 custom themes can be saved.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        _sectionTitle(context, 'الخلفيات المتحركة', 'Animated backgrounds'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('theme-background-selector'),
                  initialValue: settings.backgroundId,
                  decoration: InputDecoration(
                    labelText: _text(context, 'الخلفية', 'Background'),
                  ),
                  items: themeBackgrounds
                      .map(
                        (background) => DropdownMenuItem(
                          value: background.id,
                          child: Text(
                            isEnglish ? background.nameEn : background.nameAr,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      controller.setBackground(value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _text(context, 'سرعة الحركة', 'Animation speed'),
                      ),
                    ),
                    Text('${settings.backgroundSpeed.toStringAsFixed(1)}×'),
                  ],
                ),
                Slider(
                  key: const Key('theme-background-speed'),
                  value: settings.backgroundSpeed.clamp(.3, 1.8).toDouble(),
                  min: .3,
                  max: 1.8,
                  divisions: 15,
                  onChanged: controller.setBackgroundSpeed,
                ),
              ],
            ),
          ),
        ),
        _sectionTitle(context, 'تأثيرات السينما', 'Cinema effects'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _effectChip(context, controller, settings, 'l',
                    _text(context, 'شريط سينمائي', 'Letterbox')),
                _effectChip(context, controller, settings, 'g',
                    _text(context, 'حبيبات الفيلم', 'Film grain')),
                _effectChip(context, controller, settings, 'v',
                    _text(context, 'تعتيم الحواف', 'Vignette')),
                _effectChip(context, controller, settings, 'f',
                    _text(context, 'وهج عدسة', 'Lens flare')),
              ],
            ),
          ),
        ),
        _sectionTitle(context, 'التدرج اللوني', 'Color grading'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: themeGrades.entries.map((entry) {
                final label = switch (entry.key) {
                  '' => _text(context, 'بدون', 'None'),
                  'warm' => _text(context, 'دافئ', 'Warm'),
                  'cool' => _text(context, 'بارد', 'Cool'),
                  'bleach' => _text(context, 'مبيّض', 'Bleach'),
                  'mono' => _text(context, 'أبيض وأسود', 'Monochrome'),
                  _ => entry.value,
                };
                return ChoiceChip(
                  key: ValueKey('theme-grade-${entry.key}'),
                  label: Text(label),
                  selected: settings.colorGrade == entry.key,
                  onSelected: (_) => controller.setColorGrade(entry.key),
                );
              }).toList(),
            ),
          ),
        ),
        Card(
          child: SwitchListTile(
            key: const Key('theme-energy-saving'),
            secondary: const Icon(Icons.battery_saver_outlined),
            title: Text(_text(context, 'توفير الطاقة', 'Power saving')),
            subtitle: Text(
              _text(
                context,
                'يوقف الحركة والتأثيرات الثقيلة لتقليل استهلاك البطارية.',
                'Reduces animation and visual effects to save battery.',
              ),
            ),
            value: settings.energySaving,
            onChanged: controller.setEnergySaving,
          ),
        ),
        _sectionTitle(context, 'فحص التباين', 'Contrast check'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _contrastReport(context),
          ),
        ),
      ],
    );
  }

  Widget _effectChip(
    BuildContext context,
    AppSettingsController controller,
    AppSettings settings,
    String id,
    String label,
  ) {
    return FilterChip(
      key: ValueKey('theme-effect-$id'),
      label: Text(label),
      selected: settings.cinemaEffects.contains(id),
      onSelected: (value) => controller.toggleCinemaEffect(id, value),
    );
  }
}

class _SeedColorPickerDialog extends StatefulWidget {
  const _SeedColorPickerDialog({required this.seedColors});

  final List<Color> seedColors;

  @override
  State<_SeedColorPickerDialog> createState() => _SeedColorPickerDialogState();
}

class _SeedColorPickerDialogState extends State<_SeedColorPickerDialog> {
  late final TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: '#C026D3');
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _text(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : ar;

  void _useHexColor() {
    final value = _hexController.text.trim().replaceFirst('#', '');
    if (value.length != 6 && value.length != 8) {
      _showError(
        _text(
          'أدخل 6 أو 8 خانات HEX صحيحة.',
          'Enter a valid 6 or 8 digit HEX value.',
        ),
      );
      return;
    }

    try {
      final normalized = value.length == 6 ? 'FF$value' : value;
      final parsed = int.parse(normalized, radix: 16);
      Navigator.of(context).pop(Color(parsed));
    } on FormatException {
      _showError(
        _text('رمز اللون غير صالح.', 'The color code is invalid.'),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final heightLimit = MediaQuery.sizeOf(context).height * .55;

    return AlertDialog(
      title: Text(_text('اختر لون البداية', 'Choose a seed color')),
      content: SizedBox(
        width: 320,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: heightLimit),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('theme-seed-hex'),
                  controller: _hexController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: _text('رمز اللون HEX', 'HEX color'),
                    hintText: '#C026D3',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.seedColors.asMap().entries.map((entry) {
                    return InkWell(
                      key: ValueKey('seed-color-' + entry.key.toString()),
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => Navigator.of(context).pop(entry.value),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                          border: Border.all(color: outline, width: 1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_text('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _useHexColor,
          child: Text(_text('استخدام اللون', 'Use color')),
        ),
      ],
    );
  }
}

