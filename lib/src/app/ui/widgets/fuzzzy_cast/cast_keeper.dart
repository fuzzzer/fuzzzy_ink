import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_cast/fuzzzy_cast.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// What a keeper reacts to when its screen next shows.
enum CastKeeperCue {
  /// Something was locked: a short happy move.
  locked,

  /// Something was opened: surprised, then happy.
  opened,
}

/// The last lock or open, for the keeper of the tab the person comes back
/// to. A cue older than [fresh] is not played; one keeper plays it, once.
abstract final class CastKeeperCues {
  static const fresh = Duration(minutes: 2);

  static final latest = ValueNotifier<({CastKeeperCue cue, DateTime at})?>(
    null,
  );

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static void cue(CastKeeperCue cue) => latest.value = (cue: cue, at: clock());

  /// Takes the waiting cue, if it is still fresh.
  static CastKeeperCue? take() {
    final waiting = latest.value;
    if (waiting == null) return null;
    latest.value = null;
    return clock().difference(waiting.at) < fresh ? waiting.cue : null;
  }

  @visibleForTesting
  static void reset() {
    latest.value = null;
    clock = DateTime.now;
  }
}

/// A keeper: the character and the moves it keeps watch with, by id (ids
/// the character does not have are skipped).
class CastKeeperRole {
  const CastKeeperRole(this.character, this.watchMoves);

  final CastCharacter character;
  final List<String> watchMoves;
}

/// Who keeps which screen.
abstract final class CastKeepers {
  static const home = CastKeeperRole(CastCharacters.fuzzz, ['keeps-watch']);
  static const mySafe = CastKeeperRole(
    CastCharacters.bridgeGuard,
    ['guard-change', 'state-your-reason'],
  );
  static const settings = CastKeeperRole(
    CastCharacters.sunKeeper,
    ['still-warm', 'sunrise'],
  );
  static const howItWorks = CastKeeperRole(
    CastCharacters.sensei,
    ['slower-again', 'staff-ring'],
  );
  static const legal = CastKeeperRole(
    CastCharacters.judge,
    ['weighing', 'verdict'],
  );

  static const all = [home, mySafe, settings, howItWorks, legal];
}

/// One Fuzzzy Cast character keeping a main screen (a tab at [tabPath]). It
/// sits in one of the screen's two quiet spots ([CastKeeperSpot] 0 and 1,
/// placed by the screen clear of its buttons and text). A tap hides it and
/// it comes back in the other spot. Back on its screen after a lock it does
/// a short happy move; after an open, surprised, then happy. While it sits
/// with its screen in front it keeps watch: now and then (every 25 to 45 s)
/// it plays one of its role's watch moves, then rests still again.
///
/// It shows only while the Fuzzzy Cast setting is on and never below a
/// [SensitiveScreen] (nor while [enabled] is false); otherwise the spots take
/// no room, so the screen is exactly as without it. Screen readers skip it.
/// With reduced motion it only fades and changes its face, and never plays a
/// move.
class CastKeeper extends StatefulWidget {
  const CastKeeper({
    super.key,
    required this.role,
    required this.tabPath,
    required this.qaId,
    this.enabled = true,
    required this.child,
  });

  final CastKeeperRole role;
  final String tabPath;
  final String qaId;
  final bool enabled;
  final Widget child;

  /// The keeper's width and height in its spot.
  static const double size = 40;

  /// The first watch comes this long (plus up to [watchSpread]) after the
  /// screen shows; the next ones [watchEvery] (plus up to [watchSpread])
  /// after the last.
  static const watchFirst = Duration(seconds: 8);
  static const watchEvery = Duration(seconds: 25);
  static const watchSpread = Duration(seconds: 20);

  @override
  State<CastKeeper> createState() => _CastKeeperState();
}

class _CastKeeperState extends State<CastKeeper> with TickerProviderStateMixin {
  late final AnimationController _presence;
  late final CastMoveController _moves;
  final List<Timer> _timers = [];
  final Random _random = Random();
  Timer? _watchTimer;
  int _nextWatch = 0;

  /// A watching move is playing.
  bool _watching = false;
  GoRouter? _router;
  ValueListenable<TickerModeData>? _tickerMode;

  int _spot = 0;
  bool _moving = false;
  CastFeeling _feeling = CastFeeling.calm;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _presence = AnimationController(vsync: this, value: 1);
    _moves = CastMoveController(vsync: this);
    CastKeeperCues.latest.addListener(_maybeReact);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_maybeReact);
      _router = router?..routerDelegate.addListener(_maybeReact);
    }
    // A tab switch: the keeper's tab may be in front now.
    final tickerMode = TickerMode.getValuesNotifier(context);
    if (tickerMode != _tickerMode) {
      _tickerMode?.removeListener(_maybeReact);
      _tickerMode = tickerMode..addListener(_maybeReact);
    }
    _maybeReact();
    _watchTimer ??= _scheduleWatch(first: true);
  }

  @override
  void dispose() {
    CastKeeperCues.latest.removeListener(_maybeReact);
    _router?.routerDelegate.removeListener(_maybeReact);
    _tickerMode?.removeListener(_maybeReact);
    for (final timer in _timers) {
      timer.cancel();
    }
    _watchTimer?.cancel();
    _moves.dispose();
    _presence.dispose();
    super.dispose();
  }

  bool get _shows => widget.enabled && FuzzzyCastReaction.showsAt(context);

  /// Its tab is the screen in front (not covered by a full-screen flow).
  bool get _inFront {
    if (!(_tickerMode?.value.enabled ?? true)) return false;
    final router = _router;
    return router == null ||
        router.routerDelegate.currentConfiguration.uri.path == widget.tabPath;
  }

  void _after(Duration delay, VoidCallback action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (mounted) action();
    });
    _timers.add(timer);
  }

  List<String> get _watchIds {
    final has = {for (final move in widget.role.character.info.moves) move.id};
    return [
      for (final id in widget.role.watchMoves)
        if (has.contains(id)) id,
    ];
  }

  Timer _scheduleWatch({bool first = false}) {
    _watchTimer?.cancel();
    final base = first ? CastKeeper.watchFirst : CastKeeper.watchEvery;
    final spread = CastKeeper.watchSpread.inMilliseconds;
    return _watchTimer = Timer(
      base + Duration(milliseconds: _random.nextInt(spread)),
      _watch,
    );
  }

  /// One watching move, if the keeper is shown, in front and idle.
  void _watch() {
    if (!mounted) return;
    final ids = _watchIds;
    final idle = !_acting && !_moving && _presence.value == 1;
    if (ids.isEmpty ||
        !idle ||
        !_shows ||
        !_inFront ||
        InkMotion.isReduced(context)) {
      _scheduleWatch();
      return;
    }
    final id = ids[_nextWatch++ % ids.length];
    _watching = true;
    setState(() => _acting = true);
    _moves.play(id).then((_) {
      if (!mounted || !_watching) return;
      _watching = false;
      setState(() => _acting = false);
      _scheduleWatch();
    });
  }

  /// Ends a watching move early (a reaction or a hop comes first).
  void _stopWatching() {
    if (!_watching) return;
    _watching = false;
    _moves.stop();
    _scheduleWatch();
  }

  void _maybeReact() {
    if (!mounted || CastKeeperCues.latest.value == null) return;
    if (!_shows || !_inFront) return;
    final cue = CastKeeperCues.take();
    if (cue == null) return;
    // After the screen above has slid away.
    _after(const Duration(milliseconds: 450), () => _react(cue));
  }

  void _react(CastKeeperCue cue) {
    _stopWatching();
    _feel(
      cue == CastKeeperCue.locked ? CastFeeling.happy : CastFeeling.surprised,
    );
    if (cue == CastKeeperCue.locked) {
      _after(const Duration(milliseconds: 2400), _rest);
    } else {
      _after(
        const Duration(milliseconds: 1200),
        () => _feel(CastFeeling.happy),
      );
      _after(const Duration(milliseconds: 2800), _rest);
    }
  }

  void _feel(CastFeeling feeling) => setState(() {
        _feeling = feeling;
        _acting = true;
      });

  void _rest() => setState(() {
        _feeling = CastFeeling.calm;
        _acting = false;
      });

  /// Hides, then comes back in the other spot.
  Future<void> _hop() async {
    if (_moving) return;
    _moving = true;
    _stopWatching();
    if (_acting) _rest();
    final motion = context.fuzzzyMotion;
    _presence.duration = motion.standard;
    await _presence.reverse().orCancel.catchError((_) {});
    if (!mounted) return;
    setState(() => _spot = 1 - _spot);
    _after(const Duration(milliseconds: 700), () async {
      _presence.duration = motion.slow;
      await _presence.forward().orCancel.catchError((_) {});
      _moving = false;
    });
  }

  Widget _figure(BuildContext context) {
    final reduced = InkMotion.isReduced(context);
    final ground = Theme.of(context).brightness == Brightness.light
        ? CastGround.paper
        : CastGround.night;
    final presence = CurvedAnimation(
      parent: _presence,
      curve: context.fuzzzyMotion.slowCurve,
    );

    return ExcludeSemantics(
      child: GestureDetector(
        key: Key('keeper.${widget.qaId}'),
        behavior: HitTestBehavior.opaque,
        onTap: _hop,
        child: AnimatedBuilder(
          animation: presence,
          child: CastFigure(
            character: widget.role.character,
            body: CastBody.dark,
            ground: ground,
            background: false,
            feeling: _feeling,
            animate: _acting && !reduced,
            controller: _moves,
            size: CastKeeper.size,
          ),
          builder: (context, child) {
            final t = presence.value.clamp(0.0, 1.0);
            if (reduced) return Opacity(opacity: t, child: child);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - t)),
                child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shows =
        widget.enabled && FuzzzyCastReaction.showsAt(context, listen: true);
    return _CastKeeperScope(
      state: this,
      shows: shows,
      spot: _spot,
      feeling: _feeling,
      acting: _acting,
      child: widget.child,
    );
  }
}

class _CastKeeperScope extends InheritedWidget {
  const _CastKeeperScope({
    required this.state,
    required this.shows,
    required this.spot,
    required this.feeling,
    required this.acting,
    required super.child,
  });

  final _CastKeeperState state;
  final bool shows;
  final int spot;
  final CastFeeling feeling;
  final bool acting;

  @override
  bool updateShouldNotify(_CastKeeperScope old) =>
      shows != old.shows ||
      spot != old.spot ||
      feeling != old.feeling ||
      acting != old.acting;
}

/// One of a screen's two quiet spots for its [CastKeeper]: the keeper's
/// size while Fuzzzy Cast shows (empty when the keeper is in the other
/// spot), nothing otherwise.
class CastKeeperSpot extends StatelessWidget {
  const CastKeeperSpot(this.index, {super.key, this.padding});

  /// 0 (where the keeper starts) or 1.
  final int index;

  /// Room around the spot, taken only while the keeper shows.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_CastKeeperScope>();
    if (scope == null || !scope.shows) return const SizedBox.shrink();
    final spot = SizedBox.square(
      dimension: CastKeeper.size,
      child: scope.spot == index ? scope.state._figure(context) : null,
    );
    final padding = this.padding;
    return padding == null ? spot : Padding(padding: padding, child: spot);
  }
}
