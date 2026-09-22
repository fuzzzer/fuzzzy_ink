// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fuzzzy_seal/lib.dart';

/// The wrapped store key (0x10 blob) — the only key material Dart ever holds,
/// and only in its Argon2id-wrapped form.
class CryptoStoreKeyRepository {
  CryptoStoreKeyRepository({
    required CryptoCoreService cryptoCoreService,
  }) : _cryptoCoreService = cryptoCoreService;

  final CryptoCoreService _cryptoCoreService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: secureStorageIosOptions,
    mOptions: secureStorageMacOsOptions,
  );

  static const _storeKeyKey = 'crypto_store_key_v1';

  Future<CryptoCoreResponse<Uint8List?>> read() async {
    try {
      final wrappedBase64 = await _secureStorage.read(key: _storeKeyKey);
      if (wrappedBase64 == null) return const CryptoCoreSuccess(null);
      return CryptoCoreSuccess(base64Decode(wrappedBase64));
    } catch (ex) {
      logger.e('ERROR: $ex');
      return const CryptoCoreFailure(CryptoCoreFailureType.io);
    }
  }

  Future<CryptoCoreResponse<void>> write(Uint8List wrapped) async {
    try {
      await _secureStorage.write(
        key: _storeKeyKey,
        value: base64Encode(wrapped),
      );
      return const CryptoCoreSuccess(null);
    } catch (ex) {
      logger.e('ERROR: $ex');
      return const CryptoCoreFailure(CryptoCoreFailureType.io);
    }
  }

  /// Creates the store key wrapped under [password] when none exists yet.
  Future<CryptoCoreResponse<void>> ensureStoreKey(String password) async {
    final readRes = await read();
    if (readRes is CryptoCoreFailure) {
      return CryptoCoreFailure((readRes as CryptoCoreFailure).type);
    }
    if ((readRes as CryptoCoreSuccess<Uint8List?>).data != null) {
      return const CryptoCoreSuccess(null);
    }

    final createRes = await _cryptoCoreService.createStoreKey(password);
    if (createRes is CryptoCoreFailure) {
      return CryptoCoreFailure((createRes as CryptoCoreFailure).type);
    }

    return write((createRes as CryptoCoreSuccess<Uint8List>).data);
  }

  /// Re-wraps the store key from [oldPassword] to [newPassword] — one write.
  Future<CryptoCoreResponse<void>> rewrap({
    required String oldPassword,
    required String newPassword,
  }) async {
    final readRes = await read();
    if (readRes is CryptoCoreFailure) {
      return CryptoCoreFailure((readRes as CryptoCoreFailure).type);
    }
    final wrapped = (readRes as CryptoCoreSuccess<Uint8List?>).data;
    // `ensureStoreKey` runs at boot, so a missing blob is a broken invariant.
    if (wrapped == null) {
      return const CryptoCoreFailure(CryptoCoreFailureType.internal);
    }

    final rewrapRes = await _cryptoCoreService.rewrapStoreKey(
      wrapped: wrapped,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    if (rewrapRes is CryptoCoreFailure) {
      return CryptoCoreFailure((rewrapRes as CryptoCoreFailure).type);
    }

    return write((rewrapRes as CryptoCoreSuccess<Uint8List>).data);
  }
}
