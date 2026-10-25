import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// After an unlock the app content lifts 14 px into place and fades in (slow
/// 420 ms), once, when this widget first appears. Instant with reduced
/// motion and on private screens.
class LiftIn extends StatefulWidget {
  const LiftIn({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<LiftIn> createState() => _LiftInState();
}

class _LiftInState extends State<LiftIn> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: context.fuzzzyMotion.slow,
      value: 1,
    );
    _controller = controller;
    if (widget.enabled && InkMotion.allowsTravel(context)) {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = CurvedAnimation(
      parent: _controller!,
      curve: context.fuzzzyMotion.slowCurve,
    );

    return AnimatedBuilder(
      animation: progress,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: progress.value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - progress.value)),
          child: child,
        ),
      ),
    );
  }
}
