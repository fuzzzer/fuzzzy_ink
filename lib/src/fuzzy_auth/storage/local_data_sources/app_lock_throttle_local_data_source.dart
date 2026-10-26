import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Keeps [AppLockThrottleData] in the platform secure storage (one entry, so
/// the count and the wait are written together). Not a secret, but deleting
/// it there takes more than editing an app preferences file.
class AppLockThrottleLocalDataSource {
  AppLockThrottleLocalDataSource({
    FlutterSecureStorage? secureStorage,
    this.key = storageKey,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: secureStorageIosOptions,
              mOptions: secureStorageMacOsOptions,
            );

  /// The master password's count (the app lock, and every other form that
  /// takes the master password).
  static const storageKey = 'app_lock_throttle_v1';

  /// My safe's own password: its own count (security review 2026-10-26).
  static const vaultPasswordKey = 'vault_password_throttle_v1';

  /// The secure-storage entry this count lives in.
  final String key;

  final FlutterSecureStorage _secureStorage;

  /// `<failed attempts>;<locked-until milliseconds since epoch, or empty>`.
  Future<AppLockThrottleData> read() async {
    final value = await _secureStorage.read(key: key);
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
      key: key,
      value: '${data.failedAttempts};${untilMs ?? ''}',
    );
  }

  Future<void> delete() => _secureStorage.delete(key: key);
}
