import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A check mark that draws itself once when it appears (standard 220 ms,
/// after [delay]); with reduced motion it is simply there. Give it a new key
/// to draw it again.
class CheckDraw extends StatefulWidget {
  const CheckDraw({
    super.key,
    this.size,
    this.color,
    this.delay = Duration.zero,
    this.qaId,
  });

  /// Defaults to the kit's large icon size.
  final double? size;

  /// Defaults to the ambient icon colour, then `ink`.
  final Color? color;
  final Duration delay;
  final String? qaId;

  @override
  State<CheckDraw> createState() => _CheckDrawState();
}

class _CheckDrawState extends State<CheckDraw>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final motion = context.fuzzzyMotion;
    final total = widget.delay + motion.standard;
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    if (InkMotion.allowsInPlace(context)) {
      controller.forward();
    } else {
      controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final total = controller.duration!.inMicroseconds;
    final start = total == 0 ? 0.0 : widget.delay.inMicroseconds / total;
    final progress = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: context.fuzzzyMotion.standardCurve),
    );
    final size = widget.size ?? context.fuzzzyIconSize.l;
    final color =
        widget.color ?? IconTheme.of(context).color ?? context.fuzzzyColors.ink;

    return KeyedSubtree(
      key: widget.qaId == null ? null : Key('check.${widget.qaId}'),
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) => CustomPaint(
            painter: CheckPainter(progress: progress.value, color: color),
          ),
        ),
      ),
    );
  }
}

/// The check from the redesign's icon set (24 units, 1.5 stroke, square
/// caps), drawn up to [progress].
class CheckPainter extends CustomPainter {
  CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static Path _path(double scale) => Path()
    ..moveTo(5 * scale, 12.5 * scale)
    ..lineTo(9.5 * scale, 17 * scale)
    ..lineTo(19 * scale, 7 * scale);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final scale = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final path = _path(scale);
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
