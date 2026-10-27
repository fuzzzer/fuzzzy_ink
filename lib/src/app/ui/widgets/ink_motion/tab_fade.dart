import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The tabs' screens, each kept alive while another shows (its scroll
/// place, its own stack of screens). A newly chosen tab fades in over the
/// last one (standard 220 ms); with reduced motion it shows at once. A
/// hidden tab is offstage: it does not tick, take taps or reach a screen
/// reader.
class TabFade extends StatefulWidget {
  const TabFade({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1,
  )..addStatusListener((status) {
      if (status.isCompleted && _leaving != null) {
        setState(() => _leaving = null);
      }
    });

  /// The tab fading out under the new one, while it fades in.
  int? _leaving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fade.duration = context.fuzzzyMotion.standard;
  }

  @override
  void didUpdateWidget(TabFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    if (InkMotion.isReduced(context)) {
      _leaving = null;
      _fade.value = 1;
      return;
    }
    _leaving = oldWidget.currentIndex;
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.currentIndex;
    final opacity = CurvedAnimation(
      parent: _fade,
      curve: context.fuzzzyMotion.standardCurve,
    );
    // The chosen tab is painted last, on top; the keys keep every tab's
    // state as the order changes.
    final order = [
      for (var i = 0; i < widget.children.length; i++)
        if (i != current) i,
      current,
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final i in order)
          KeyedSubtree(
            key: ValueKey(i),
            child: Offstage(
              offstage: i != current && i != _leaving,
              child: TickerMode(
                enabled: i == current,
                child: IgnorePointer(
                  ignoring: i != current,
                  child: ExcludeSemantics(
                    excluding: i != current,
                    child: FadeTransition(
                      opacity:
                          i == current ? opacity : kAlwaysCompleteAnimation,
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
