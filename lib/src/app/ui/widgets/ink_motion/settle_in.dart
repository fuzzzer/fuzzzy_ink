import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A mark or glyph settles into place once (scale 0.9 to 1, slow 420 ms):
/// the mark on the lock screen, a hero glyph after a result. It stays where
/// it is, so it is allowed on private screens; still with reduced motion.
class SettleIn extends StatefulWidget {
  const SettleIn({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<SettleIn> createState() => _SettleInState();
}

class _SettleInState extends State<SettleIn>
    with SingleTickerProviderStateMixin {
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
    if (widget.enabled && InkMotion.allowsInPlace(context)) {
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
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1).animate(
        CurvedAnimation(
          parent: _controller!,
          curve: context.fuzzzyMotion.slowCurve,
        ),
      ),
      child: widget.child,
    );
  }
}
