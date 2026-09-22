// ignore_for_file: avoid_redundant_argument_values

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_seal/lib.dart';

enum BiometricScope { chat, vault }

extension on BiometricScope {
  String get _flagKey => 'biometric_enabled_$name';
  String get _storageName => 'fuzzy_biometric_password_$name';

  String get _accessTitle {
    switch (this) {
      case BiometricScope.chat:
        return 'Authenticate to unlock chats';
      case BiometricScope.vault:
        return 'Authenticate to unlock vault';
    }
  }

  String get _androidTitle {
    switch (this) {
      case BiometricScope.chat:
        return 'Unlock Fuzzzy Seal';
      case BiometricScope.vault:
        return 'Unlock Fuzzy Vault';
    }
  }
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
      promptInfo: PromptInfo(
        iosPromptInfo: IosPromptInfo(
          saveTitle: 'Authenticate to save password',
          accessTitle: scope._accessTitle,
        ),
        androidPromptInfo: AndroidPromptInfo(
          title: scope._androidTitle,
          subtitle: scope._accessTitle,
        ),
      ),
    );
  }
}
