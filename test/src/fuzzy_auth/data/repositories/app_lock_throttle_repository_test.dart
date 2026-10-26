import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The wrong-password wait (security review 2026-10-26): moving the device
/// clock forward does not end a wait while the app runs, and the safe's own
/// password has its own count.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime wall;
  AppLockThrottleRepository master() => AppLockThrottleRepository(
        localDataSource: AppLockThrottleLocalDataSource(),
        now: () => wall,
      );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    wall = DateTime(2026, 10, 26, 12);
  });

  Future<void> fail(AppLockThrottleRepository repository, int times) async {
    for (var i = 0; i < times; i++) {
      await repository.save((await repository.read()).afterFailure(wall));
    }
  }

  test('a wait survives the clock moved forward while the app runs', () async {
    final repository = master();
    await fail(repository, AppLockThrottleData.freeAttempts);
    expect((await repository.read()).remainingAt(wall), isNot(Duration.zero));

    wall = wall.add(const Duration(days: 1));
    final remaining = (await repository.read()).remainingAt(wall);
    expect(remaining, greaterThan(const Duration(seconds: 25)));
    expect(remaining, lessThanOrEqualTo(const Duration(seconds: 30)));
  });

  test('a clock moved back never makes the wait longer than its step',
      () async {
    final repository = master();
    await fail(repository, AppLockThrottleData.freeAttempts);
    wall = wall.subtract(const Duration(days: 3));
    expect(
      (await repository.read()).remainingAt(wall),
      lessThanOrEqualTo(const Duration(seconds: 30)),
    );
  });

  test('a right password ends the wait on both clocks', () async {
    final repository = master();
    await fail(repository, AppLockThrottleData.freeAttempts);
    await repository.clear();
    wall = wall.add(const Duration(days: 1));
    expect((await repository.read()).remainingAt(wall), Duration.zero);
    expect((await repository.read()).failedAttempts, 0);
  });

  test("My safe's own password keeps its own count", () async {
    final repository = master();
    final vault = VaultPasswordThrottleRepository(
      localDataSource: AppLockThrottleLocalDataSource(
        key: AppLockThrottleLocalDataSource.vaultPasswordKey,
      ),
      now: () => wall,
    );
    await fail(vault, 2);
    expect((await vault.read()).failedAttempts, 2);
    expect((await repository.read()).failedAttempts, 0);
  });
}
