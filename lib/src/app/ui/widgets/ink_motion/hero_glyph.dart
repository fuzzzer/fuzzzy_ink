import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// How a [HeroGlyph]'s circle is filled.
enum HeroGlyphTone {
  /// Surface with a hairline.
  plain,

  /// Inverted ink (the main-action colours).
  inverted,

  /// Warning soft fill.
  warning,
}

/// The picture slot of a result screen when Fuzzzy Cast is off: a 92 px
/// circle holding one glyph. [drawCheck] draws a check instead of [icon]
/// (connected, checked); [settle] lets it settle in once.
class HeroGlyph extends StatelessWidget {
  const HeroGlyph({
    super.key,
    this.icon,
    this.tone = HeroGlyphTone.plain,
    this.drawCheck = false,
    this.settle = false,
    this.qaId,
  });

  final IconData? icon;
  final HeroGlyphTone tone;
  final bool drawCheck;
  final bool settle;
  final String? qaId;

  /// The circle's size from the design (`.hero .glyph`).
  static const double diameter = 92;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final (Color fill, Color foreground, Color border) = switch (tone) {
      HeroGlyphTone.plain => (colors.surface, colors.ink, colors.line),
      HeroGlyphTone.inverted => (
          colors.actionPrimaryBg,
          colors.actionPrimaryFg,
          colors.actionPrimaryBg,
        ),
      HeroGlyphTone.warning => (
          colors.warning.withValues(alpha: 0.12),
          colors.warning,
          colors.warning.withValues(alpha: 0),
        ),
    };
    const glyphSize = diameter * 0.44;

    final circle = Container(
      key: qaId == null ? null : Key('hero.$qaId'),
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: drawCheck
          ? CheckDraw(
              size: glyphSize,
              color: foreground,
              delay: InkMotionTiming.checkDelay,
            )
          : Icon(icon, size: glyphSize, color: foreground),
    );

    return ExcludeSemantics(
      child: SettleIn(enabled: settle, child: circle),
    );
  }
}

/// "Lock done": the hero lock's shackle snaps shut once (3.5 px down,
/// standard 220 ms after 140 ms) while the glyph settles (scale 0.9 to 1,
/// slow 420 ms), with one medium buzz on phones. With reduced motion the
/// closed lock is simply there, and the buzz stays.
class LockSnapGlyph extends StatefulWidget {
  const LockSnapGlyph({super.key, this.buzz = true, this.qaId});

  /// Off where the caller buzzes itself.
  final bool buzz;
  final String? qaId;

  @override
  State<LockSnapGlyph> createState() => _LockSnapGlyphState();
}

class _LockSnapGlyphState extends State<LockSnapGlyph>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final motion = context.fuzzzyMotion;
    final controller = AnimationController(
      vsync: this,
      duration: InkMotionTiming.shackleDelay + motion.standard,
      value: 1,
    );
    _controller = controller;
    if (InkMotion.allowsInPlace(context)) controller.forward(from: 0);
    if (widget.buzz) unawaited(InkHaptics.medium());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final controller = _controller!;
    final total = controller.duration!.inMicroseconds;
    final shut = CurvedAnimation(
      parent: controller,
      curve: Interval(
        InkMotionTiming.shackleDelay.inMicroseconds / total,
        1,
        curve: context.fuzzzyMotion.standardCurve,
      ),
    );

    return ExcludeSemantics(
      child: SettleIn(
        child: Container(
          key: widget.qaId == null ? null : Key('hero.${widget.qaId}'),
          width: HeroGlyph.diameter,
          height: HeroGlyph.diameter,
          decoration: BoxDecoration(
            color: colors.actionPrimaryBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SizedBox.square(
            dimension: HeroGlyph.diameter * 0.44,
            child: AnimatedBuilder(
              animation: shut,
              builder: (context, _) => CustomPaint(
                painter: _LockPainter(
                  shackleLift: 3.5 * (1 - shut.value),
                  color: colors.actionPrimaryFg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The redesign's lock glyph (24 units): body, shackle and keyhole. The
/// shackle is drawn [shackleLift] units above its closed place.
class _LockPainter extends CustomPainter {
  _LockPainter({required this.shackleLift, required this.color});

  final double shackleLift;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s
      ..strokeCap = StrokeCap.square;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5 * s, 10.5 * s, 14 * s, 10 * s),
          Radius.circular(s),
        ),
        paint,
      )
      ..drawLine(Offset(12 * s, 14.5 * s), Offset(12 * s, 16.5 * s), paint);
    final lift = shackleLift * s;
    final shackle = Path()
      ..moveTo(8 * s, 10.5 * s - lift)
      ..lineTo(8 * s, 7.5 * s - lift)
      // The top half of a circle of 4 units around (12, 7.5).
      ..arcTo(
        Rect.fromCircle(center: Offset(12 * s, 7.5 * s - lift), radius: 4 * s),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(16 * s, 10.5 * s - lift);
    canvas.drawPath(shackle, paint);
  }

  @override
  bool shouldRepaint(_LockPainter oldDelegate) =>
      oldDelegate.shackleLift != shackleLift || oldDelegate.color != color;
}
