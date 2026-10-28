import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Keeps Settings → Other apps and the person last used in each other app,
/// each as a blob sealed under the store key, in the secure storage (as the
/// auto-lock times are kept). Storage errors are thrown to the repository.
class FuzzAnywhereLocalDataSource {
  FuzzAnywhereLocalDataSource({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: secureStorageIosOptions,
              mOptions: secureStorageMacOsOptions,
            );

  static const settingsKey = 'fuzz_anywhere_settings_v1';
  static const appPeopleKey = 'fuzz_anywhere_app_people_v1';

  final FlutterSecureStorage _secureStorage;

  Future<Uint8List?> read(String key) async {
    final value = await _secureStorage.read(key: key);
    return value == null ? null : base64Decode(value);
  }

  Future<void> write(String key, Uint8List sealed) =>
      _secureStorage.write(key: key, value: base64Encode(sealed));

  Future<void> delete(String key) => _secureStorage.delete(key: key);
}
