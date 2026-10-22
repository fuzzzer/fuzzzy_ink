// ignore_for_file: avoid_redundant_argument_values

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_ink/lib.dart';

enum BiometricScope { chat, vault }

extension on BiometricScope {
  String get _flagKey => 'biometric_enabled_$name';

  /// Written with every copy made under [biometricKeyVersion].
  String get _versionKey => 'biometric_key_version_$name';

  /// Android derives the Keystore key alias from this name, and a key keeps
  /// the parameters it was made with: the per-use biometric-only copies use a
  /// new name so they can never reuse an old key. iOS/macOS keep the old
  /// name — their Keychain item was already biometric-only.
  String get _storageName => _androidKeysOutdated
      ? 'fuzzy_biometric_password_v2_$name'
      : _legacyStorageName;

  String get _legacyStorageName => 'fuzzy_biometric_password_$name';
}

/// Copies written before this version sit, on Android, under a Keystore key
/// that also accepts the device PIN and stays usable for 30 s after any
/// unlock, with no prompt (security review 2026-10-22, item 2).
@visibleForTesting
const biometricKeyVersion = '2';

/// Only Android copies made before [biometricKeyVersion] are weaker than the
/// current ones; iOS/macOS items had the same access control then.
bool get _androidKeysOutdated =>
    defaultTargetPlatform == TargetPlatform.android;

/// The system fingerprint / Face ID prompt in the app's language (T-0413).
/// Chats reuse the unlock screen's title; the Android cancel button reuses
/// the dialogs' Cancel.
@visibleForTesting
PromptInfo biometricPromptInfo(
  BiometricScope scope,
  FuzzzyInkLocalizations localizations,
) {
  final accessTitle = switch (scope) {
    BiometricScope.chat => localizations.biometricUnlockChats,
    BiometricScope.vault => localizations.biometricUnlockVault,
  };
  final darwinPromptInfo = IosPromptInfo(
    saveTitle: localizations.biometricSavePassword,
    accessTitle: accessTitle,
  );
  return PromptInfo(
    iosPromptInfo: darwinPromptInfo,
    macOsPromptInfo: darwinPromptInfo,
    androidPromptInfo: AndroidPromptInfo(
      title: switch (scope) {
        BiometricScope.chat => localizations.chatUnlockTitle,
        BiometricScope.vault => localizations.biometricUnlockVaultTitle,
      },
      subtitle: accessTitle,
      negativeButton: localizations.cancel,
    ),
  );
}

class BiometricAuthRepository {
  BiometricAuthRepository({
    FlutterSecureStorage? secureStorage,
    BiometricStorage? biometricStorage,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: secureStorageIosOptions,
              mOptions: secureStorageMacOsOptions,
            ),
        _biometricStorage = biometricStorage ?? BiometricStorage();

  final FlutterSecureStorage _secureStorage;
  final BiometricStorage _biometricStorage;

  Future<bool> canUseBiometrics() async {
    final response = await _biometricStorage.canAuthenticate();
    logger.i('BiometricStorage.canAuthenticate -> $response');
    return response == CanAuthenticateResponse.success;
  }

  /// A copy made before [biometricKeyVersion] is dropped here first, so it
  /// reads as disabled and the user falls back to the password.
  Future<bool> isEnabled(BiometricScope scope) async {
    await discardOutdatedCopy(scope);
    final value = await _secureStorage.read(key: scope._flagKey);
    return value == 'true';
  }

  /// One-time upgrade: deletes an Android copy made before
  /// [biometricKeyVersion] (its key cannot be changed in place) and turns the
  /// scope off, so the user turns biometrics on again once. Returns whether a
  /// copy was dropped. Never throws.
  Future<bool> discardOutdatedCopy(BiometricScope scope) async {
    try {
      if (await _secureStorage.read(key: scope._flagKey) != 'true') {
        return false;
      }
      if (await _secureStorage.read(key: scope._versionKey) ==
          biometricKeyVersion) {
        return false;
      }
      if (!_androidKeysOutdated) {
        await _secureStorage.write(
          key: scope._versionKey,
          value: biometricKeyVersion,
        );
        return false;
      }
      logger.i('Biometric copy predates biometric-only keys: scope=$scope');
      await _secureStorage.delete(key: scope._flagKey);
    } catch (e) {
      logger.w('Outdated biometric copy not checked: scope=$scope, $e');
      return false;
    }
    // The flag is gone, so the old copy is never read again; deleting its
    // file and key is clean-up.
    try {
      final legacy = await _biometricStorage.getStorage(
        scope._legacyStorageName,
        options: storageOptions,
      );
      await legacy.delete();
    } catch (e) {
      logger.w('Outdated biometric copy not deleted: scope=$scope, $e');
    }
    return true;
  }

  Future<void> enable(BiometricScope scope, String password) async {
    logger.i('Biometric enable: scope=$scope');
    final storage = await _openStorage(scope);
    await storage.write(password);
    await _secureStorage.write(
      key: scope._versionKey,
      value: biometricKeyVersion,
    );
    await _secureStorage.write(key: scope._flagKey, value: 'true');
    logger.i('Biometric enabled: scope=$scope');
  }

  Future<String?> retrievePassword(BiometricScope scope) async {
    logger.i('Biometric retrieve: scope=$scope');
    final storage = await _openStorage(scope);
    final value = await storage.read();
    logger
        .i('Biometric retrieve done: scope=$scope, hasValue=${value != null}');
    return value;
  }

  Future<void> disable(BiometricScope scope) async {
    await _secureStorage.delete(key: scope._flagKey);
    try {
      final storage = await _openStorage(scope);
      await storage.delete();
    } catch (_) {
      // Storage may already be cleared or biometrics unavailable; ignore.
    }
  }

  Future<BiometricStorageFile> _openStorage(BiometricScope scope) {
    return _biometricStorage.getStorage(
      scope._storageName,
      options: storageOptions,
      promptInfo: biometricPromptInfo(scope, currentContextLocalization),
    );
  }

  /// `-1`: a biometric prompt on every read, strong biometrics only. Android
  /// makes the key with `AUTH_BIOMETRIC_STRONG` and timeout 0 (a positive
  /// value would also accept the device PIN and leave a no-prompt window);
  /// iOS/macOS get no Touch ID / Face ID reuse window.
  @visibleForTesting
  static final storageOptions = StorageFileInitOptions(
    authenticationValidityDurationSeconds: -1,
    androidBiometricOnly: true,
    darwinBiometricOnly: true,
  );
}
