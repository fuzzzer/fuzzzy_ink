import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Keeps the auto-lock settings as a blob sealed under the store key, in the
/// secure storage. Storage errors are thrown to the repository.
class AutoLockSettingsLocalDataSource {
  AutoLockSettingsLocalDataSource({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: secureStorageIosOptions,
              mOptions: secureStorageMacOsOptions,
            );

  static const storageKey = 'auto_lock_settings_v1';

  final FlutterSecureStorage _secureStorage;

  Future<Uint8List?> read() async {
    final value = await _secureStorage.read(key: storageKey);
    return value == null ? null : base64Decode(value);
  }

  Future<void> write(Uint8List sealed) =>
      _secureStorage.write(key: storageKey, value: base64Encode(sealed));
}
