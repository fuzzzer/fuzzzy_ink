import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The whole-app auto-lock. While the app is unlocked it locks after the
/// idle time without a touch, a scroll or a key press, and once the app has
/// been in the background longer than the background time (measured again
/// on return, since a phone may freeze timers in the background). Locking
/// closes the store, which wipes its key in the core.
///
/// The time away is measured on the wall clock and on a monotonic clock, and
/// the longer one counts; a wall clock that went backwards locks at once
/// (security review 2026-10-26). So setting the device clock back, or
/// forward, never skips the lock on return. (The monotonic clock may pause
/// while a phone sleeps; the wall clock covers that.)
class AppAutoLock extends StatefulWidget {
  const AppAutoLock({super.key, required this.child});

  final Widget child;

  /// The wall clock; tests set it to move the device clock.
  @visibleForTesting
  static DateTime Function() wallClock = DateTime.now;

  /// Whether the time away calls for the lock: negative on the wall clock
  /// (the clock was set back), or [background] or more on either clock.
  @visibleForTesting
  static bool isAwayTooLong({
    required Duration wall,
    required Duration monotonic,
    required Duration background,
  }) =>
      wall.isNegative || wall >= background || monotonic >= background;

  @override
  State<AppAutoLock> createState() => _AppAutoLockState();
}

class _AppAutoLockState extends State<AppAutoLock> with WidgetsBindingObserver {
  Timer? _idleTimer;
  Timer? _backgroundTimer;
  DateTime? _leftAt;
  final Stopwatch _away = Stopwatch();

  FuzzyAuthStore get _authStore => context.read<FuzzyAuthStore>();
  AutoLockSettings get _settings => context.read<AutoLockCubit>().state;
  bool get _isUnlocked => _authStore.state.status.hasAccess;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _idleTimer?.cancel();
    _backgroundTimer?.cancel();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    _restartIdleTimer();
    return false;
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    if (!_isUnlocked) return;
    _idleTimer = Timer(_settings.idle, _lock);
  }

  void _lock() {
    _idleTimer?.cancel();
    _backgroundTimer?.cancel();
    if (_isUnlocked) _authStore.lock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_leftAt != null || !_isUnlocked) return;
        _leftAt = AppAutoLock.wallClock();
        _away
          ..reset()
          ..start();
        final background = _settings.background;
        if (background == Duration.zero) {
          _lock();
        } else {
          _backgroundTimer?.cancel();
          _backgroundTimer = Timer(background, _lock);
        }
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        _away.stop();
        _backgroundTimer?.cancel();
        if (leftAt != null &&
            AppAutoLock.isAwayTooLong(
              wall: AppAutoLock.wallClock().difference(leftAt),
              monotonic: _away.elapsed,
              background: _settings.background,
            )) {
          _lock();
        } else {
          _restartIdleTimer();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FuzzyAuthStore, FuzzyAuthState>(
          listenWhen: (previous, current) =>
              previous.status.hasAccess != current.status.hasAccess,
          listener: (context, state) {
            if (state.status.hasAccess) {
              // The settings are sealed under the store key: they load once
              // the store is open.
              context.read<AutoLockCubit>().load().then((_) {
                if (mounted) _restartIdleTimer();
              });
              _restartIdleTimer();
            } else {
              _idleTimer?.cancel();
              _backgroundTimer?.cancel();
              _leftAt = null;
            }
          },
        ),
        BlocListener<AutoLockCubit, AutoLockSettings>(
          listener: (_, __) => _restartIdleTimer(),
        ),
      ],
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _restartIdleTimer(),
        onPointerMove: (_) => _restartIdleTimer(),
        onPointerSignal: (_) => _restartIdleTimer(),
        child: widget.child,
      ),
    );
  }
}
