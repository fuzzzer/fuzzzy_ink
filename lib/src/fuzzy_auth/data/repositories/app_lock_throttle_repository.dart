import 'package:fuzzzy_ink/src/src.dart';

/// Never throws. When the secure storage cannot be read the app cannot be
/// unlocked either (the wrapped store key lives there too), so a read failure
/// answers "no wait" and a write failure is logged.
///
/// The wait is kept on the wall clock (so it survives a restart) and, while
/// the app runs, on a monotonic clock as well (security review 2026-10-26):
/// moving the device clock forward does not end a wait in the running app;
/// [read] answers whichever end is later. A clock moved back never makes a
/// wait longer than its step ([AppLockThrottleData.remainingAt]). A restart
/// after moving the clock forward still ends it: the stored end is all a new
/// process has.
class AppLockThrottleRepository {
  AppLockThrottleRepository({
    required AppLockThrottleLocalDataSource localDataSource,
    DateTime Function()? now,
  })  : _localDataSource = localDataSource,
        _now = now ?? DateTime.now;

  final AppLockThrottleLocalDataSource _localDataSource;
  final DateTime Function() _now;
  final Stopwatch _monotonic = Stopwatch()..start();

  /// The end of the current wait on [_monotonic], or `null`.
  Duration? _monotonicEnd;

  Future<AppLockThrottleData> read() async {
    AppLockThrottleData data;
    try {
      data = await _localDataSource.read();
    } catch (e) {
      logger.w('App-lock throttle could not be read: $e');
      return AppLockThrottleData.none;
    }
    final end = _monotonicEnd;
    if (end == null || data.failedAttempts == 0) return data;
    final left = end - _monotonic.elapsed;
    if (left <= Duration.zero) return data;
    final monotonicUntil = _now().add(left);
    final until = data.lockedUntil;
    if (until != null && !until.isBefore(monotonicUntil)) return data;
    return AppLockThrottleData(
      failedAttempts: data.failedAttempts,
      lockedUntil: monotonicUntil,
    );
  }

  Future<void> save(AppLockThrottleData data) async {
    final until = data.lockedUntil;
    if (until != null) {
      var left = until.difference(_now());
      final cap = AppLockThrottleData.waitAfter(data.failedAttempts);
      if (left > cap) left = cap;
      _monotonicEnd = left > Duration.zero ? _monotonic.elapsed + left : null;
    }
    try {
      await _localDataSource.write(data);
    } catch (e) {
      logger.w('App-lock throttle could not be saved: $e');
    }
  }

  Future<void> clear() async {
    _monotonicEnd = null;
    try {
      await _localDataSource.delete();
    } catch (e) {
      logger.w('App-lock throttle could not be cleared: $e');
    }
  }
}

/// My safe's own password: the same rules as the master password, its own
/// count (security review 2026-10-26).
class VaultPasswordThrottleRepository extends AppLockThrottleRepository {
  VaultPasswordThrottleRepository({
    required super.localDataSource,
    super.now,
  });
}
