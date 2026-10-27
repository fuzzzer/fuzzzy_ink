import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The one page transition for every full-screen screen (the tabs fade
/// instead, [TabFade]): the iPhone's own slide, with its back-swipe from the
/// left edge, on every platform. With reduced motion the screen fades in
/// place, and the back-swipe still works: the screen fades with the finger
/// instead of sliding.
class InkPageTransitionsBuilder extends PageTransitionsBuilder {
  const InkPageTransitionsBuilder();

  static const _slide = CupertinoPageTransitionsBuilder();

  /// For `ThemeData.pageTransitionsTheme`: this transition on every platform.
  static final theme = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const InkPageTransitionsBuilder(),
    },
  );

  @override
  Duration get transitionDuration => _slide.transitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _delegated;

  /// How the screen below moves as a new one slides over it: not at all
  /// with reduced motion.
  static Widget? _delegated(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (InkMotion.isReduced(context)) return child;
    return CupertinoPageTransition.delegatedTransition(
      context,
      animation,
      secondaryAnimation,
      allowSnapshotting,
      child,
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!InkMotion.isReduced(context)) {
      return _slide.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FadeTransition(
      opacity: animation,
      child: CupertinoRouteTransitionMixin.buildPageTransitions(
        route,
        context,
        kAlwaysCompleteAnimation,
        kAlwaysDismissedAnimation,
        child,
      ),
    );
  }
}
