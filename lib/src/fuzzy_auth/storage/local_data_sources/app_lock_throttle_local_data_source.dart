import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Keeps [AppLockThrottleData] in the platform secure storage (one entry, so
/// the count and the wait are written together). Not a secret, but deleting
/// it there takes more than editing an app preferences file.
class AppLockThrottleLocalDataSource {
  AppLockThrottleLocalDataSource({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: secureStorageIosOptions,
              mOptions: secureStorageMacOsOptions,
            );

  static const storageKey = 'app_lock_throttle_v1';

  final FlutterSecureStorage _secureStorage;

  /// `<failed attempts>;<locked-until milliseconds since epoch, or empty>`.
  Future<AppLockThrottleData> read() async {
    final value = await _secureStorage.read(key: storageKey);
    if (value == null) return AppLockThrottleData.none;
    final parts = value.split(';');
    final attempts = int.tryParse(parts.first);
    if (attempts == null || attempts < 0) return AppLockThrottleData.none;
    final untilMs = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return AppLockThrottleData(
      failedAttempts: attempts,
      lockedUntil:
          untilMs == null ? null : DateTime.fromMillisecondsSinceEpoch(untilMs),
    );
  }

  Future<void> write(AppLockThrottleData data) {
    final untilMs = data.lockedUntil?.millisecondsSinceEpoch;
    return _secureStorage.write(
      key: storageKey,
      value: '${data.failedAttempts};${untilMs ?? ''}',
    );
  }

  Future<void> delete() => _secureStorage.deleteIfPresent(storageKey);
}
