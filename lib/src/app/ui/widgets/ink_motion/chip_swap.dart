import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A status chip that changes in place: the new one rises 3 px and fades in
/// (standard 220 ms) where the old one was. Give each state's chip its own
/// key. Instant with reduced motion and on private screens.
class ChipSwap extends StatelessWidget {
  const ChipSwap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.fuzzzyMotion;
    final moves = InkMotion.allowsTravel(context);

    return AnimatedSwitcher(
      duration: moves ? motion.standard : Duration.zero,
      switchInCurve: motion.standardCurve,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 3 * (1 - animation.value)),
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }
}
