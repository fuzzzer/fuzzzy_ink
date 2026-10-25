import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The master key's blobs in the platform secure storage: the master key
/// wrapped under the master password and under the recovery key (0x10), the
/// store key wrapped under the master key (0x20), the recovery lock under the
/// store key (0x20) and, for a vault with its own password, the vault key
/// sealed to that lock (0x11). Only wrapped forms ever reach Dart; storage
/// errors are thrown to the repository.
class MasterKeyLocalDataSource {
  MasterKeyLocalDataSource({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: secureStorageIosOptions,
              mOptions: secureStorageMacOsOptions,
            );

  static const passwordWrapKey = 'master_key_password_v2';
  static const recoveryWrapKey = 'master_key_recovery_v2';
  static const storeWrapKey = 'store_key_wrap_v2';
  static const recoveryLockKey = 'recovery_lock_v2';
  static const vaultRecoveryKey = 'vault_key_recovery_v2';

  /// The store key wrapped straight under the app-lock password, as builds
  /// before the master password kept it (the lock could be off then).
  static const legacyStoreKeyKey = 'crypto_store_key_v1';

  final FlutterSecureStorage _secureStorage;

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

  Future<bool> hasLegacyKey() =>
      _secureStorage.containsKey(key: legacyStoreKeyKey);

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
  /// settings.
  Future<void> deleteAll() => _secureStorage.deleteAll();

  Future<Uint8List?> _readBytes(String key) async {
    final value = await _secureStorage.read(key: key);
    return value == null ? null : base64Decode(value);
  }

  Future<void> _writeBytes(String key, Uint8List bytes) =>
      _secureStorage.write(key: key, value: base64Encode(bytes));
}
