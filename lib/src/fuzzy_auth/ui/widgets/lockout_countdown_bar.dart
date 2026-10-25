import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The truthful lockout bar under the Unlock button: 2 px, full when a wait
/// begins, empty exactly when the next password may be tried. It follows the
/// auth store's real time left ([FuzzyAuthState.lockoutRemaining], updated
/// every second) and moves linearly between updates. Nothing when there is
/// no wait, and nothing with reduced motion (the countdown text says it).
class LockoutCountdownBar extends StatefulWidget {
  const LockoutCountdownBar({super.key, required this.remaining});

  final Duration remaining;

  @override
  State<LockoutCountdownBar> createState() => _LockoutCountdownBarState();
}

class _LockoutCountdownBarState extends State<LockoutCountdownBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
  );

  /// The length of the current wait: the most time left seen since it began.
  Duration _wait = Duration.zero;

  @override
  void initState() {
    super.initState();
    _follow(widget.remaining);
  }

  @override
  void didUpdateWidget(LockoutCountdownBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining) _follow(widget.remaining);
  }

  void _follow(Duration remaining) {
    if (remaining <= Duration.zero) {
      _wait = Duration.zero;
      _controller.value = 0;
      return;
    }
    if (remaining > _wait) _wait = remaining;
    _controller
      ..value = remaining.inMicroseconds / _wait.inMicroseconds
      ..animateTo(0, duration: remaining);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.remaining <= Duration.zero || InkMotion.isReduced(context)) {
      return const SizedBox.shrink();
    }
    final colors = context.fuzzzyColors;

    return ExcludeSemantics(
      child: ClipRRect(
        key: const Key('lockout.bar'),
        borderRadius: BorderRadius.circular(context.fuzzzyRadius.s),
        child: SizedBox(
          height: 2,
          child: ColoredBox(
            color: colors.track,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: _controller.value,
                child: ColoredBox(color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
