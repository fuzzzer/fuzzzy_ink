import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The master key's blobs in the platform secure storage: the master key
/// wrapped under the master password and under the recovery key (0x10), the
/// store key wrapped under the master key (0x20), the recovery lock under the
/// store key (0x20) and, for a vault with its own password, the vault key
/// sealed to that lock (0x11). Only wrapped forms ever reach Dart; storage
/// errors are thrown to the repository.
class MasterKeyLocalDataSource {
  MasterKeyLocalDataSource({
    FlutterSecureStorage? secureStorage,
    FlutterSecureStorage? legacyStorage,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: secureStorageIosOptions,
              mOptions: secureStorageMacOsOptions,
            ),
        _legacyStorage = legacyStorage ??
            const FlutterSecureStorage(
              iOptions: legacySecureStorageIosOptions,
              mOptions: legacySecureStorageMacOsOptions,
            );

  static const passwordWrapKey = 'master_key_password_v2';
  static const recoveryWrapKey = 'master_key_recovery_v2';
  static const storeWrapKey = 'store_key_wrap_v2';
  static const recoveryLockKey = 'recovery_lock_v2';
  static const vaultRecoveryKey = 'vault_key_recovery_v2';

  /// The store key wrapped straight under the app-lock password, as builds
  /// before the master password kept it (the lock could be off then).
  static const legacyStoreKeyKey = 'crypto_store_key_v1';

  /// Every name an earlier build kept under the plugin's shared default
  /// keychain service (before `secureStorageService`): looked for as
  /// leftovers and removed one by one, never with a wildcard — in the macOS
  /// login keychain that service is shared with other apps.
  static const legacyNamespaceKeys = [
    legacyStoreKeyKey,
    passwordWrapKey,
    recoveryWrapKey,
    storeWrapKey,
    recoveryLockKey,
    vaultRecoveryKey,
    'app_lock_throttle_v1',
    'auto_lock_settings_v1',
    'biometric_enabled_chat',
    'biometric_enabled_vault',
    'biometric_key_version_chat',
    'biometric_key_version_vault',
    'biometric_legacy_cleanup_chat',
    'biometric_legacy_cleanup_vault',
  ];

  /// The keys whose presence under the old service means an earlier build
  /// was set up here.
  static const _legacyMarkers = [
    legacyStoreKeyKey,
    passwordWrapKey,
    storeWrapKey,
  ];

  final FlutterSecureStorage _secureStorage;
  final FlutterSecureStorage _legacyStorage;

  /// `null` until the first run has finished: the password wrap is written
  /// last, so a run that stopped half-way reads as "not set up".
  Future<MasterKeyBlobs?> read() async {
    final passwordWrap = await _readBytes(passwordWrapKey);
    final storeWrap = await _readBytes(storeWrapKey);
    if (passwordWrap == null || storeWrap == null) return null;
    return MasterKeyBlobs(
      passwordWrap: passwordWrap,
      storeWrap: storeWrap,
      recoveryWrap: await _readBytes(recoveryWrapKey),
      recoveryLock: await _readBytes(recoveryLockKey),
      vaultRecovery: await _readBytes(vaultRecoveryKey),
    );
  }

  /// Whether an earlier build left its keys: the app-lock store key of the
  /// builds before the master password (under either service), or a master
  /// key kept under the old shared service.
  Future<bool> hasLegacyKey() async {
    if (await _secureStorage.containsKey(key: legacyStoreKeyKey)) return true;
    for (final key in _legacyMarkers) {
      if (await _legacyStorage.containsKey(key: key)) return true;
    }
    return false;
  }

  /// The store wrap and the recovery wrap first, the password wrap last: it
  /// is the mark that the first run is complete.
  Future<void> writeSetup(MasterKeyBlobs blobs) async {
    await _writeBytes(storeWrapKey, blobs.storeWrap);
    final recoveryWrap = blobs.recoveryWrap;
    if (recoveryWrap != null) {
      await _writeBytes(recoveryWrapKey, recoveryWrap);
    }
    await _writeBytes(passwordWrapKey, blobs.passwordWrap);
  }

  Future<void> writePasswordWrap(Uint8List wrap) =>
      _writeBytes(passwordWrapKey, wrap);

  /// A recovery key the user saved: the vault copy and the lock first, the
  /// recovery wrap last — its presence is what "a recovery key is set" means.
  /// Without [vaultRecovery] any older vault copy is removed.
  Future<void> writeRecovery({
    required Uint8List recoveryWrap,
    required Uint8List recoveryLock,
    Uint8List? vaultRecovery,
  }) async {
    if (vaultRecovery != null) {
      await _writeBytes(vaultRecoveryKey, vaultRecovery);
    } else {
      await _secureStorage.delete(key: vaultRecoveryKey);
    }
    await _writeBytes(recoveryLockKey, recoveryLock);
    await _writeBytes(recoveryWrapKey, recoveryWrap);
  }

  /// Ends the recovery key: its wrap first (the master key's path), then the
  /// vault copy and the lock.
  Future<void> deleteRecovery() async {
    await _secureStorage.delete(key: recoveryWrapKey);
    await _secureStorage.delete(key: vaultRecoveryKey);
    await _secureStorage.delete(key: recoveryLockKey);
  }

  Future<void> writeVaultRecovery(Uint8List recovery) =>
      _writeBytes(vaultRecoveryKey, recovery);

  Future<void> deleteVaultRecovery() =>
      _secureStorage.delete(key: vaultRecoveryKey);

  /// Every entry this app keeps in the secure storage: the key blobs, the
  /// legacy key, the biometric flags, the attempt counter and the sealed
  /// settings. Throws when this app's own entries could not be removed.
  /// What an earlier build left under the old shared service is removed too,
  /// as far as the system lets this build: an entry it refuses (one an
  /// earlier, differently signed build made) cannot be read by this build
  /// either, so it does not stop a fresh start.
  Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
    for (final key in legacyNamespaceKeys) {
      try {
        await _legacyStorage.delete(key: key);
      } catch (ex) {
        logger.w('Leftover keychain entry not removed: ${_describe(ex)}');
      }
    }
  }

  /// A storage error for the log: its type and, for a platform error, the
  /// system's code and message (never a value).
  static String _describe(Object ex) => ex is PlatformException
      ? 'PlatformException(${ex.code}, ${ex.message})'
      : '${ex.runtimeType}';

  Future<Uint8List?> _readBytes(String key) async {
    final value = await _secureStorage.read(key: key);
    return value == null ? null : base64Decode(value);
  }

  Future<void> _writeBytes(String key, Uint8List bytes) =>
      _secureStorage.write(key: key, value: base64Encode(bytes));
}
