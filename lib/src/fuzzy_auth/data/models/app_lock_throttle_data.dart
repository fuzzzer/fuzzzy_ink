/// Wrong app-lock passwords in a row and the wait they impose (security
/// review 2026-10-22, item 6). Persisted, so a restart does not end a wait.
class AppLockThrottleData {
  const AppLockThrottleData({
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  static const none = AppLockThrottleData();

  /// Wrong passwords allowed before the first wait.
  static const freeAttempts = 5;

  /// The wait after the 5th, 6th, … wrong password; the last one repeats.
  static const waits = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
  ];

  final int failedAttempts;
  final DateTime? lockedUntil;

  static Duration waitAfter(int failedAttempts) {
    if (failedAttempts < freeAttempts) return Duration.zero;
    final index = failedAttempts - freeAttempts;
    return index < waits.length ? waits[index] : waits.last;
  }

  AppLockThrottleData afterFailure(DateTime now) {
    final attempts = failedAttempts + 1;
    final wait = waitAfter(attempts);
    return AppLockThrottleData(
      failedAttempts: attempts,
      lockedUntil: wait == Duration.zero ? null : now.add(wait),
    );
  }

  /// Never longer than the wait this attempt count earns, so a clock moved
  /// backwards cannot lock the user out for longer than that.
  Duration remainingAt(DateTime now) {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(now);
    if (left <= Duration.zero) return Duration.zero;
    final cap = waitAfter(failedAttempts);
    return left > cap ? cap : left;
  }

  @override
  bool operator ==(Object other) =>
      other is AppLockThrottleData &&
      other.failedAttempts == failedAttempts &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode => Object.hash(failedAttempts, lockedUntil);

  @override
  String toString() =>
      'AppLockThrottleData(failedAttempts: $failedAttempts, lockedUntil: $lockedUntil)';
}
