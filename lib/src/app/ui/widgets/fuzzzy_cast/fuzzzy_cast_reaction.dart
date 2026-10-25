import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_cast/fuzzzy_cast.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Where a [FuzzzyCastReaction] sits.
enum FuzzzyCastPlacement {
  /// The big-picture slot of a result screen (about 124 x 128).
  hero,

  /// Beside a confirmation, at the start of a toast (46 px).
  toast,
}

/// Fuzzz, the Fuzzzy Cast's default face, reacting to [moment] in one of the
/// two places the design allows (DESIGN.md section 9).
///
/// It shows only while the Fuzzzy Cast setting is on and never below a
/// [SensitiveScreen]; otherwise [fallback] (the glyph response) shows
/// instead, so Fuzzz replaces the glyph, never adds to it. Fuzzz pops in
/// (slow 420 ms), plays the feeling or act once, then rests still. The same
/// moment plays at most once a minute (a burst plays only the first); within
/// that minute Fuzzz is shown resting. With reduced motion it is a still
/// Fuzzz that fades in. It is not tappable and screen readers skip it.
class FuzzzyCastReaction extends StatelessWidget {
  const FuzzzyCastReaction({
    super.key,
    required this.moment,
    this.fallback = const SizedBox.shrink(),
    this.placement = FuzzzyCastPlacement.hero,
    this.qaId,
  });

  final FuzzzyCastMoment moment;
  final Widget fallback;
  final FuzzzyCastPlacement placement;
  final String? qaId;

  /// Whether Fuzzz may show at [context]: the setting is on and the screen
  /// is not private.
  static bool showsAt(BuildContext context) {
    final settings = context.watch<FuzzzyCastSettingsCubit?>();
    return (settings?.state.isEnabled ?? false) &&
        !SensitiveScreen.isIn(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!showsAt(context)) return fallback;
    return _FuzzzyCastFigure(
      key: ValueKey(moment),
      moment: moment,
      placement: placement,
      qaId: qaId,
    );
  }
}

/// Remembers when each moment last played, so a burst plays only the first
/// and the same reaction plays at most once a minute.
abstract final class FuzzzyCastThrottle {
  static const window = Duration(minutes: 1);

  static final Map<FuzzzyCastMoment, DateTime> _lastPlayed = {};

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Claims a play of [moment] now; false while it played within [window].
  static bool claim(FuzzzyCastMoment moment) {
    final now = clock();
    final last = _lastPlayed[moment];
    if (last != null && now.difference(last) < window) return false;
    _lastPlayed[moment] = now;
    return true;
  }

  @visibleForTesting
  static void reset() {
    _lastPlayed.clear();
    clock = DateTime.now;
  }
}

class _FuzzzyCastFigure extends StatefulWidget {
  const _FuzzzyCastFigure({
    super.key,
    required this.moment,
    required this.placement,
    this.qaId,
  });

  final FuzzzyCastMoment moment;
  final FuzzzyCastPlacement placement;
  final String? qaId;

  @override
  State<_FuzzzyCastFigure> createState() => _FuzzzyCastFigureState();
}

class _FuzzzyCastFigureState extends State<_FuzzzyCastFigure>
    with TickerProviderStateMixin {
  late final CastMoveController _moves = CastMoveController(vsync: this);
  AnimationController? _entrance;
  Timer? _rest;
  bool _plays = false;
  bool _resting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance != null) return;
    final moment = widget.moment;
    _plays = FuzzzyCastThrottle.claim(moment);
    _resting = !_plays;

    final entrance = AnimationController(
      vsync: this,
      duration: context.fuzzzyMotion.slow,
      value: _plays ? 0 : 1,
    );
    _entrance = entrance;
    if (_plays) unawaited(entrance.forward());

    final moveId = moment.moveId;
    if (_plays && moveId != null && !InkMotion.isReduced(context)) {
      unawaited(_moves.play(moveId, loop: moment.loops));
    }
    if (_plays && !moment.loops) {
      _rest = Timer(moment.length, () {
        if (!mounted) return;
        _moves.stop();
        setState(() => _resting = true);
      });
    }
  }

  @override
  void dispose() {
    _rest?.cancel();
    _moves.dispose();
    _entrance?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.placement == FuzzzyCastPlacement.hero;
    final width = hero ? 124.0 : 46.0;
    final reduced = InkMotion.isReduced(context);
    final ground = Theme.of(context).brightness == Brightness.light
        ? CastGround.paper
        : CastGround.night;
    final entrance = CurvedAnimation(
      parent: _entrance!,
      curve: context.fuzzzyMotion.slowCurve,
    );

    final figure = CastFigure(
      character: CastCharacters.fuzzz,
      body: CastBody.dark,
      ground: ground,
      background: false,
      feeling: _resting ? CastFeeling.calm : widget.moment.feeling,
      animate: !_resting && !reduced,
      controller: _moves,
      size: width,
    );

    return ExcludeSemantics(
      child: IgnorePointer(
        child: KeyedSubtree(
          key: Key('fuzzzy_cast.${widget.qaId ?? widget.moment.name}'),
          child: AnimatedBuilder(
            animation: entrance,
            child: figure,
            builder: (context, child) {
              final t = entrance.value;
              if (reduced) return Opacity(opacity: t, child: child);
              return Opacity(
                opacity: t.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - t)),
                  child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
