import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The wait schedule after wrong app-lock passwords (security review
/// 2026-10-22, item 6) and how it is kept in secure storage.
void main() {
  final now = DateTime(2026, 10, 22, 12);

  test(
      'no wait for the first four wrong passwords, then 30 s, 1, 2, 5, 10 '
      'and at most 15 minutes', () {
    final waits = [
      for (var attempts = 1; attempts <= 12; attempts++)
        AppLockThrottleData.waitAfter(attempts),
    ];
    expect(waits, const [
      Duration.zero,
      Duration.zero,
      Duration.zero,
      Duration.zero,
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 10),
      Duration(minutes: 15),
      Duration(minutes: 15),
      Duration(minutes: 15),
    ]);
  });

  test('afterFailure counts up and sets the end of the wait', () {
    var data = AppLockThrottleData.none;
    for (var i = 0; i < 4; i++) {
      data = data.afterFailure(now);
    }
    expect(data.lockedUntil, isNull);
    data = data.afterFailure(now);
    expect(data.failedAttempts, 5);
    expect(data.lockedUntil, now.add(const Duration(seconds: 30)));
    expect(
      data.remainingAt(now.add(const Duration(seconds: 5))),
      const Duration(seconds: 25),
    );
    expect(
      data.remainingAt(now.add(const Duration(minutes: 1))),
      Duration.zero,
    );
  });

  test('a clock moved backwards never makes the wait longer than earned', () {
    final data = AppLockThrottleData(
      failedAttempts: 5,
      lockedUntil: now.add(const Duration(seconds: 30)),
    );
    expect(
      data.remainingAt(now.subtract(const Duration(days: 3))),
      const Duration(seconds: 30),
    );
  });

  group('secure storage round trip', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('writes and reads back the count and the end of the wait', () async {
      final source = AppLockThrottleLocalDataSource();
      final data = AppLockThrottleData(
        failedAttempts: 6,
        lockedUntil: now.add(const Duration(minutes: 1)),
      );
      await source.write(data);
      expect(await AppLockThrottleLocalDataSource().read(), data);

      await source.write(const AppLockThrottleData(failedAttempts: 2));
      expect(
        await source.read(),
        const AppLockThrottleData(failedAttempts: 2),
      );

      await source.delete();
      expect(await source.read(), AppLockThrottleData.none);
    });

    test('an unreadable entry reads as no wait', () async {
      FlutterSecureStorage.setMockInitialValues({
        AppLockThrottleLocalDataSource.storageKey: 'garbage',
      });
      expect(
        await AppLockThrottleLocalDataSource().read(),
        AppLockThrottleData.none,
      );
    });
  });
}
