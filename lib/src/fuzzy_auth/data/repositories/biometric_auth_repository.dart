// ignore_for_file: avoid_redundant_argument_values

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_ink/lib.dart';

enum BiometricScope { chat, vault }

extension on BiometricScope {
  String get _flagKey => 'biometric_enabled_$name';
  String get _storageName => 'fuzzy_biometric_password_$name';
}

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
  BiometricAuthRepository();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: secureStorageIosOptions,
    mOptions: secureStorageMacOsOptions,
  );

  Future<bool> canUseBiometrics() async {
    final response = await BiometricStorage().canAuthenticate();
    logger.i('BiometricStorage.canAuthenticate -> $response');
    return response == CanAuthenticateResponse.success;
  }

  Future<bool> isEnabled(BiometricScope scope) async {
    final value = await _secureStorage.read(key: scope._flagKey);
    return value == 'true';
  }

  Future<void> enable(BiometricScope scope, String password) async {
    logger.i('Biometric enable: scope=$scope');
    final storage = await _openStorage(scope);
    await storage.write(password);
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
    return BiometricStorage().getStorage(
      scope._storageName,
      options: StorageFileInitOptions(
        authenticationValidityDurationSeconds: 30,
        androidBiometricOnly: true,
        darwinBiometricOnly: true,
      ),
      promptInfo: biometricPromptInfo(scope, currentContextLocalization),
    );
  }
}
