import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A lightweight, native Canvas background inspired by the supplied HTML
/// studio. It avoids WebGL/WebView and automatically reduces work in power
/// saving mode or when the app is not active.
class ThemeBackdrop extends StatefulWidget {
  const ThemeBackdrop({
    required this.backgroundId,
    required this.speed,
    required this.energySaving,
    required this.effects,
    required this.colorGrade,
    super.key,
  });

  final String backgroundId;
  final double speed;
  final bool energySaving;
  final Set<String> effects;
  final String colorGrade;

  @override
  State<ThemeBackdrop> createState() => _ThemeBackdropState();
}

class _ThemeBackdropState extends State<ThemeBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (18000 / widget.speed).round()),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ThemeBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _controller.duration =
          Duration(milliseconds: (18000 / widget.speed).round());
    }
    if (oldWidget.energySaving != widget.energySaving ||
        oldWidget.backgroundId != widget.backgroundId) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final shouldAnimate = _appActive &&
        !widget.energySaving &&
        widget.backgroundId != 'none';
    if (shouldAnimate) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = switch (widget.colorGrade) {
      'warm' => const Color(0xFFFFA64D),
      'cool' => const Color(0xFF65B9FF),
      'bleach' => const Color(0xFFE4E4E4),
      'mono' => const Color(0xFF8D8D8D),
      _ => Colors.transparent,
    };

    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _ThemeBackdropPainter(
                  progress: _controller.value,
                  backgroundId: widget.backgroundId,
                  base: scheme.surfaceContainerLowest,
                  primary: scheme.primary,
                  secondary: scheme.secondary,
                  reduced: widget.energySaving,
                ),
                child: const SizedBox.expand(),
              ),
              if (widget.colorGrade.isNotEmpty)
                ColoredBox(color: tint.withValues(alpha: .055)),
              if (widget.effects.contains('v'))
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -.1),
                      radius: 1.05,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: widget.energySaving ? .14 : .25,
                        ),
                      ],
                      stops: const [.50, 1],
                    ),
                  ),
                ),
              if (widget.effects.contains('g') && !widget.energySaving)
                CustomPaint(
                  painter: _GrainPainter(
                    progress: _controller.value,
                    tint: scheme.onSurface,
                  ),
                  child: const SizedBox.expand(),
                ),
              if (widget.effects.contains('l'))
                Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    heightFactor: .045,
                    widthFactor: 1,
                    child: const ColoredBox(color: Colors.black),
                  ),
                ),
              if (widget.effects.contains('l'))
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: .045,
                    widthFactor: 1,
                    child: const ColoredBox(color: Colors.black),
                  ),
                ),
              if (widget.effects.contains('f') && !widget.energySaving)
                Align(
                  alignment: Alignment(
                    0,
                    math.sin(_controller.value * math.pi * 2) * .24,
                  ),
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          scheme.secondary.withValues(alpha: .05),
                          scheme.secondary.withValues(alpha: .42),
                          scheme.secondary.withValues(alpha: .05),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.secondary.withValues(alpha: .25),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeBackdropPainter extends CustomPainter {
  const _ThemeBackdropPainter({
    required this.progress,
    required this.backgroundId,
    required this.base,
    required this.primary,
    required this.secondary,
    required this.reduced,
  });

  final double progress;
  final String backgroundId;
  final Color base;
  final Color primary;
  final Color secondary;
  final bool reduced;

  void _glow(Canvas canvas, Size size, Offset center, double radius, Color color,
      double opacity) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: opacity * .22),
          color.withValues(alpha: 0),
        ],
        stops: const [0, .38, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(base, BlendMode.src);
    if (backgroundId == 'none' || size.isEmpty) return;
    final phase = progress * math.pi * 2;
    final low = reduced ? .55 : 1.0;
    final width = size.width;
    final height = size.height;
    final radius = math.max(width, height) * .7;

    switch (backgroundId) {
      case 'aurora':
      case 'fluid':
        for (var i = 0; i < 4; i++) {
          final angle = phase * (reduced ? .1 : .24) + i * 1.55;
          final center = Offset(
            width * (.5 + .39 * math.sin(angle)),
            height * (.40 + .26 * math.cos(angle * .8 + i)),
          );
          _glow(
            canvas,
            size,
            center,
            radius * (.65 + i * .08),
            i.isEven ? primary : secondary,
            .13 * low,
          );
        }
      case 'leaks':
      case 'smoke':
        _glow(
          canvas,
          size,
          Offset(width * (.12 + .09 * math.sin(phase * .3)), height * .18),
          radius * .76,
          primary,
          .17 * low,
        );
        _glow(
          canvas,
          size,
          Offset(width * (.92 + .06 * math.cos(phase * .2)), height * .72),
          radius * .70,
          secondary,
          .15 * low,
        );
      case 'flow':
      case 'plasma':
        for (var i = 0; i < 5; i++) {
          final path = Path()..moveTo(0, height);
          for (double x = 0; x <= width + 10; x += 10) {
            final y = height * (.43 + i * .105) +
                math.sin(x * .006 + phase * .3 + i) *
                    height *
                    .035 *
                    (1 + i * .2);
            path.lineTo(x, y);
          }
          path
            ..lineTo(width, height)
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..color = (i.isEven ? primary : secondary)
                  .withValues(alpha: .035 * low)
              ..style = PaintingStyle.fill,
          );
        }
      case 'particles':
        final count = reduced ? 22 : 48;
        for (var i = 0; i < count; i++) {
          final seed = i * 12.9898;
          final x = ((math.sin(seed) + 1) / 2) * width;
          final y = ((math.sin(seed * 1.7 + 4.3) + 1) / 2) * height;
          final drift = reduced ? 0 : math.sin(phase + i) * 10;
          canvas.drawCircle(
            Offset(x + drift, y),
            i % 5 == 0 ? 2 : 1.2,
            Paint()
              ..color = primary.withValues(alpha: .30 * low),
          );
        }
      case 'stars':
        final count = reduced ? 25 : 60;
        for (var i = 0; i < count; i++) {
          final seed = i * 7.31;
          final x = ((math.sin(seed) + 1) / 2) * width;
          final y = ((math.sin(seed * 2.3 + 1.2) + 1) / 2) * height;
          canvas.drawCircle(
            Offset(x, y),
            i % 7 == 0 ? 2 : 1,
            Paint()
              ..color = secondary.withValues(
                alpha: (.18 + .14 * math.sin(phase + i).abs()) * low,
              ),
          );
        }
      case 'grid':
        final paint = Paint()
          ..color = primary.withValues(alpha: .13 * low)
          ..strokeWidth = 1;
        for (var i = 0; i <= 16; i++) {
          final x = width * i / 16;
          canvas.drawLine(
            Offset(width / 2 + (x - width / 2) * .30, height * .55),
            Offset(x, height),
            paint,
          );
        }
        for (var i = 0; i < 12; i++) {
          final t = i / 12;
          final y = height * (.55 + .45 * t * t);
          canvas.drawLine(Offset(0, y), Offset(width, y), paint);
        }
      case 'code':
        final paint = TextPainter(textDirection: TextDirection.ltr);
        const chars = '01';
        for (var i = 0; i < (width / 24).ceil(); i++) {
          for (var j = 0; j < (height / 48).ceil(); j++) {
            if ((i * 7 + j * 11) % 4 != 0) continue;
            final char = chars[(i + j) % chars.length];
            paint.text = TextSpan(
              text: char,
              style: TextStyle(
                color: primary.withValues(alpha: .32 * low),
                fontSize: 12,
              ),
            );
            paint.layout();
            final drift = reduced ? 0 : phase * 8;
            paint.paint(
              canvas,
              Offset(i * 24, (j * 48 + drift) % height),
            );
          }
        }
      default:
        _glow(
          canvas,
          size,
          Offset(width * .5, height * .5),
          radius,
          primary,
          .07 * low,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.backgroundId != backgroundId ||
      oldDelegate.base != base ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.reduced != reduced;
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = tint.withValues(alpha: .045)
      ..strokeWidth = 1;
    final offset = (progress * 19).floor();
    for (var i = 0; i < 260; i++) {
      final x = ((i * 73 + offset * 11) % 997) / 997 * size.width;
      final y = ((i * 137 + offset * 7) % 991) / 991 * size.height;
      canvas.drawPoints(
        PointMode.points,
        [Offset(x, y)],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.tint != tint;
}
