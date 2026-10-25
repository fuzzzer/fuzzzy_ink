import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Where it went": when [play] is on as the row appears, a soft success tint
/// and a 3 px left bar fade out once over 1.6 s. Nothing with reduced motion
/// or on a private screen (the message that says where it went stays).
class RowTint extends StatefulWidget {
  const RowTint({super.key, required this.child, this.play = false});

  final Widget child;
  final bool play;

  @override
  State<RowTint> createState() => _RowTintState();
}

class _RowTintState extends State<RowTint> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: InkMotionTiming.rowTint,
    value: 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.play && InkMotion.allowsTravel(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final success = context.fuzzzyColors.success;
    final fade = CurvedAnimation(
      parent: _controller,
      curve: context.fuzzzyMotion.standardCurve,
    );

    return AnimatedBuilder(
      animation: fade,
      child: widget.child,
      builder: (context, child) {
        final strength = 1 - fade.value;
        if (strength <= 0) return child!;
        return DecoratedBox(
          key: const Key('row_tint.active'),
          decoration: BoxDecoration(
            color: success.withValues(alpha: 0.10 * strength),
            border: Border(
              left: BorderSide(
                color: success.withValues(alpha: strength),
                width: 3,
              ),
            ),
          ),
          child: child,
        );
      },
    );
  }
}
