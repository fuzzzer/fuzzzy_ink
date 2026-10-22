import 'package:fuzzzy_ink/src/src.dart';

/// Never throws. When the secure storage cannot be read the app cannot be
/// unlocked either (the wrapped store key lives there too), so a read failure
/// answers "no wait" and a write failure is logged.
class AppLockThrottleRepository {
  AppLockThrottleRepository({
    required AppLockThrottleLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final AppLockThrottleLocalDataSource _localDataSource;

  Future<AppLockThrottleData> read() async {
    try {
      return await _localDataSource.read();
    } catch (e) {
      logger.w('App-lock throttle could not be read: $e');
      return AppLockThrottleData.none;
    }
  }

  Future<void> save(AppLockThrottleData data) async {
    try {
      await _localDataSource.write(data);
    } catch (e) {
      logger.w('App-lock throttle could not be saved: $e');
    }
  }

  Future<void> clear() async {
    try {
      await _localDataSource.delete();
    } catch (e) {
      logger.w('App-lock throttle could not be cleared: $e');
    }
  }
}
