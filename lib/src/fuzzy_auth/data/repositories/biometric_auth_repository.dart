// ignore_for_file: avoid_redundant_argument_values

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  /// Set while the old Android copy still has to be deleted; cleared once it
  /// is gone, so a failed delete is tried again at the next start.
  String get _legacyCleanupKey => 'biometric_legacy_cleanup_$name';
}

/// Copies written before this version sit, on Android, under a Keystore key
/// that also accepts the device PIN and stays usable for 30 s after any
/// unlock, with no prompt (security review 2026-10-22, item 2).
@visibleForTesting
const biometricKeyVersion = '2';

/// Only Android copies made before [biometricKeyVersion] are weaker than the
/// current ones; iOS/macOS items had the same access control then.
bool get _androidKeysOutdated => _isAndroid;

bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

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
    InkDeviceChannel device = const InkDeviceChannel(),
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: secureStorageIosOptions,
              mOptions: secureStorageMacOsOptions,
            ),
        _biometricStorage = biometricStorage ?? BiometricStorage(),
        _device = device;

  final FlutterSecureStorage _secureStorage;
  final BiometricStorage _biometricStorage;
  final InkDeviceChannel _device;

  /// Strong biometrics are there and enrolled. On iOS and macOS the
  /// plugin's own check also passes with only a passcode (it asks for
  /// "device owner" authentication), which offered the fingerprint step on a
  /// phone with no face or finger enrolled (QA 2026-10-26), so Face ID /
  /// Touch ID enrolment is asked natively as well.
  Future<bool> canUseBiometrics() async {
    final response = await _biometricStorage.canAuthenticate();
    logger.i('BiometricStorage.canAuthenticate -> $response');
    if (response != CanAuthenticateResponse.success) return false;
    if (!InkDeviceChannel.isAvailable) return true;
    try {
      return await _device.hasStrongBiometrics();
    } on PlatformException catch (e) {
      logger.w('Biometric enrolment unknown: ${e.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
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
  /// copy was dropped. An old copy whose delete failed is deleted on a later
  /// call (the next start). Never throws.
  Future<bool> discardOutdatedCopy(BiometricScope scope) async {
    await _retryLegacyCleanup(scope);
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
      // Noted before the flag goes, so the clean-up is never forgotten.
      await _secureStorage.write(key: scope._legacyCleanupKey, value: 'true');
      await _secureStorage.delete(key: scope._flagKey);
    } catch (e) {
      logger.w('Outdated biometric copy not checked: scope=$scope, $e');
      return false;
    }
    // The flag is gone, so the old copy is never read again; deleting its
    // file and key is clean-up.
    await _deleteLegacyCopy(scope);
    return true;
  }

  Future<void> _retryLegacyCleanup(BiometricScope scope) async {
    try {
      if (await _secureStorage.read(key: scope._legacyCleanupKey) != 'true') {
        return;
      }
    } catch (e) {
      logger.w('Outdated biometric clean-up not checked: scope=$scope, $e');
      return;
    }
    await _deleteLegacyCopy(scope);
  }

  /// Deletes the old copy's file and key, then the pending note; on failure
  /// the note stays for the next try.
  Future<void> _deleteLegacyCopy(BiometricScope scope) async {
    try {
      final legacy = await _biometricStorage.getStorage(
        scope._legacyStorageName,
        options: storageOptions,
      );
      await legacy.delete();
      await _secureStorage.delete(key: scope._legacyCleanupKey);
    } catch (e) {
      logger.w('Outdated biometric copy not deleted: scope=$scope, $e');
    }
  }

  /// Never throws. On Android a key that needs strong biometrics on every
  /// use cannot be made while none is enrolled — the case of a device with
  /// only weak (class 2) biometrics, which `canAuthenticate` still reports
  /// as available — so a failure there that is not the prompt's own error is
  /// [BiometricEnableResult.notStrongEnough].
  Future<BiometricEnableResult> enable(
    BiometricScope scope,
    String password,
  ) async {
    logger.i('Biometric enable: scope=$scope');
    try {
      final storage = await _openStorage(scope);
      await storage.write(password);
    } on AuthException catch (e) {
      logger.w('Biometric enable refused: scope=$scope, ${e.code}');
      return switch (e.code) {
        AuthExceptionCode.userCanceled ||
        AuthExceptionCode.canceled ||
        AuthExceptionCode.timeout =>
          BiometricEnableResult.cancelled,
        _ => BiometricEnableResult.failed,
      };
    } catch (e) {
      logger.w('Biometric enable failed: scope=$scope, $e');
      return _isAndroid
          ? BiometricEnableResult.notStrongEnough
          : BiometricEnableResult.failed;
    }
    try {
      await _secureStorage.write(
        key: scope._versionKey,
        value: biometricKeyVersion,
      );
      await _secureStorage.write(key: scope._flagKey, value: 'true');
    } catch (e) {
      logger.w('Biometric flag not saved: scope=$scope, $e');
      return BiometricEnableResult.failed;
    }
    logger.i('Biometric enabled: scope=$scope');
    return BiometricEnableResult.enabled;
  }

  /// Never throws. Only a missing copy — the plugin deletes one whose key a
  /// new enrolment invalidated (Android), or the Keychain no longer returns
  /// it (`biometryCurrentSet`, iOS/macOS) — is [BiometricCopyGone]; a
  /// cancel, a sensor lockout or any other error is [BiometricNotRead].
  Future<BiometricRead> readPassword(BiometricScope scope) async {
    logger.i('Biometric read: scope=$scope');
    try {
      final storage = await _openStorage(scope);
      final value = await storage.read();
      logger.i('Biometric read done: scope=$scope, hasValue=${value != null}');
      return value == null
          ? const BiometricCopyGone()
          : BiometricPassword(value);
    } catch (e) {
      logger.w('Biometric read did not unlock: scope=$scope, $e');
      return const BiometricNotRead();
    }
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
