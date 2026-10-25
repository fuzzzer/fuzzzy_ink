import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fuzzzy_ink/lib.dart';

class VaultCryptoRepository {
  const VaultCryptoRepository({
    required this.passwordStrengthService,
    required this.cryptoCoreService,
    required this.chatAuthRepository,
  });

  final PasswordStrengthService passwordStrengthService;
  final CryptoCoreService cryptoCoreService;

  /// Holds the master key's password wrap, which a vault under the master
  /// key needs to open, and the recovery key's blobs: its lock, which a vault
  /// with its own password is sealed to, and that sealed copy.
  final ChatAuthRepository chatAuthRepository;

  /// The vault key never exists in Dart: the metadata keeps it wrapped
  /// (`verificationToken`), and [unlock] hands back a handle. By default the
  /// master key wraps it, so [password] is the master password; with
  /// [ownPassword] the vault gets [password] as its own ("good" or better)
  /// and, when a recovery key is kept, a copy sealed to its lock.
  Future<VaultResponse<VaultMetadata>> initializeVault(
    String password, {
    bool ownPassword = false,
  }) async {
    try {
      final CryptoCoreResponse<CryptoCoreVaultInit> initRes;
      if (ownPassword) {
        if (!passwordStrengthService.isStrongEnough(password)) {
          return const VaultFailure(VaultFailureType.weakPassword);
        }
        final lockRes = await _recoveryLock();
        if (lockRes is VaultFailure<Uint8List?>) {
          return VaultFailure(lockRes.type, message: lockRes.message);
        }
        initRes = await cryptoCoreService.vaultInit(
          password,
          recoveryLock: (lockRes as VaultSuccess<Uint8List?>).data,
        );
      } else {
        final wrapRes = await chatAuthRepository.passwordWrap();
        if (wrapRes is CryptoCoreFailure<Uint8List>) {
          return VaultFailure(
            _failureOf(wrapRes.type),
            message: wrapRes.type.name,
          );
        }
        initRes = await cryptoCoreService.vaultInitWithMaster(
          passwordWrap: (wrapRes as CryptoCoreSuccess<Uint8List>).data,
          masterPassword: password,
        );
      }
      if (initRes is CryptoCoreFailure<CryptoCoreVaultInit>) {
        return VaultFailure(
          _failureOf(initRes.type),
          message: initRes.type.name,
        );
      }
      final created = (initRes as CryptoCoreSuccess<CryptoCoreVaultInit>).data;
      // The caller unlocks with the password it already has; this handle is
      // not kept.
      await created.key.close();
      created.key.dispose();
      // A new vault replaces any copy an earlier vault left.
      final copyRes = await _saveRecoveryCopy(created.recovery);
      if (copyRes != null) return VaultFailure(copyRes);

      final metadata = VaultMetadata(
        vaultId: generateId(),
        verificationToken: base64Encode(created.wrapped),
        createdAt: DateTime.now(),
        lastUnlockedAt: DateTime.now(),
      );

      return VaultSuccess(metadata);
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  /// Whether the vault has its own password (`true`) or opens with the
  /// master password (`false`), read from the wrapped key's type.
  VaultResponse<bool> usesOwnPassword(VaultMetadata metadata) {
    try {
      final res = cryptoCoreService.vaultUsesOwnPassword(
        base64Decode(metadata.verificationToken),
      );
      if (res is CryptoCoreFailure<bool>) {
        return VaultFailure(
          VaultFailureType.fileCorrupted,
          message: res.type.name,
        );
      }
      return VaultSuccess((res as CryptoCoreSuccess<bool>).data);
    } catch (e) {
      return VaultFailure(
        VaultFailureType.fileCorrupted,
        message: e.toString(),
      );
    }
  }

  /// Opens the vault with whichever password it uses: its own, or the
  /// master password.
  Future<VaultResponse<VaultKey>> unlock(
    String password,
    VaultMetadata metadata,
  ) async {
    try {
      final ownRes = usesOwnPassword(metadata);
      if (ownRes is VaultFailure<bool>) {
        return VaultFailure(ownRes.type, message: ownRes.message);
      }
      final wrapped = base64Decode(metadata.verificationToken);
      final CryptoCoreResponse<VaultKey> keyRes;
      if ((ownRes as VaultSuccess<bool>).data) {
        keyRes = await cryptoCoreService.vaultUnlock(
          wrapped: wrapped,
          password: password,
        );
      } else {
        final wrapRes = await chatAuthRepository.passwordWrap();
        if (wrapRes is CryptoCoreFailure<Uint8List>) {
          return VaultFailure(
            _failureOf(wrapRes.type),
            message: wrapRes.type.name,
          );
        }
        keyRes = await cryptoCoreService.vaultUnlockWithMaster(
          passwordWrap: (wrapRes as CryptoCoreSuccess<Uint8List>).data,
          masterPassword: password,
          wrapped: wrapped,
        );
      }
      if (keyRes is CryptoCoreFailure<VaultKey>) {
        return VaultFailure(_failureOf(keyRes.type), message: keyRes.type.name);
      }
      return VaultSuccess((keyRes as CryptoCoreSuccess<VaultKey>).data);
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  /// Gives a vault the master password opens its own [newPassword] ("good"
  /// or better). The same key is re-wrapped; no item is re-encrypted.
  Future<VaultResponse<VaultMetadata>> useOwnPassword({
    required String masterPassword,
    required String newPassword,
    required VaultMetadata metadata,
  }) async {
    try {
      if (!passwordStrengthService.isStrongEnough(newPassword)) {
        return const VaultFailure(VaultFailureType.weakPassword);
      }
      final wrapRes = await chatAuthRepository.passwordWrap();
      if (wrapRes is CryptoCoreFailure<Uint8List>) {
        return VaultFailure(
          _failureOf(wrapRes.type),
          message: wrapRes.type.name,
        );
      }
      final lockRes = await _recoveryLock();
      if (lockRes is VaultFailure<Uint8List?>) {
        return VaultFailure(lockRes.type, message: lockRes.message);
      }
      final rewrapRes = await cryptoCoreService.vaultUseOwnPassword(
        passwordWrap: (wrapRes as CryptoCoreSuccess<Uint8List>).data,
        masterPassword: masterPassword,
        wrapped: base64Decode(metadata.verificationToken),
        newPassword: newPassword,
        recoveryLock: (lockRes as VaultSuccess<Uint8List?>).data,
      );
      if (rewrapRes is CryptoCoreFailure<CryptoCoreVaultWrapping>) {
        return VaultFailure(
          _failureOf(rewrapRes.type),
          message: rewrapRes.type.name,
        );
      }
      final changed =
          (rewrapRes as CryptoCoreSuccess<CryptoCoreVaultWrapping>).data;
      // The copy first: once the metadata names the new wrapping, the master
      // password no longer opens the vault and the copy is the way back.
      final copyRes = await _saveRecoveryCopy(changed.recovery);
      if (copyRes != null) return VaultFailure(copyRes);
      return _withToken(CryptoCoreSuccess(changed.wrapped), metadata);
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  /// Puts a vault with its own password back under the master key.
  Future<VaultResponse<VaultMetadata>> useMasterPassword({
    required String vaultPassword,
    required String masterPassword,
    required VaultMetadata metadata,
  }) async {
    try {
      final wrapRes = await chatAuthRepository.passwordWrap();
      if (wrapRes is CryptoCoreFailure<Uint8List>) {
        return VaultFailure(
          _failureOf(wrapRes.type),
          message: wrapRes.type.name,
        );
      }
      final rewrapRes = await cryptoCoreService.vaultUseMasterPassword(
        wrapped: base64Decode(metadata.verificationToken),
        vaultPassword: vaultPassword,
        passwordWrap: (wrapRes as CryptoCoreSuccess<Uint8List>).data,
        masterPassword: masterPassword,
      );
      return _withToken(rewrapRes, metadata);
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  /// A change of the vault's own password re-wraps the vault key only — the
  /// key itself does not change, so no item is re-encrypted.
  Future<VaultResponse<VaultMetadata>> rewrap(
    String oldPassword,
    String newPassword,
    VaultMetadata metadata,
  ) async {
    try {
      if (!passwordStrengthService.isStrongEnough(newPassword)) {
        return const VaultFailure(VaultFailureType.weakPassword);
      }

      final rewrapRes = await cryptoCoreService.vaultRewrap(
        wrapped: base64Decode(metadata.verificationToken),
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return _withToken(rewrapRes, metadata);
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  /// After a switch back to the master password has been saved: the copy
  /// sealed to the recovery lock is no longer needed (the recovery key
  /// reaches the vault through the master key).
  Future<VaultResponse<void>> dropRecoveryCopy() async {
    final failure = await _saveRecoveryCopy(null);
    return failure == null ? const VaultSuccess(null) : VaultFailure(failure);
  }

  /// Whether a recovery key is kept (its wrap and its lock), so a vault that
  /// gets its own password is sealed to it.
  Future<bool> hasRecoveryKey() async {
    final blobsRes = await chatAuthRepository.keyBlobs();
    return blobsRes is CryptoCoreSuccess<MasterKeyBlobs> &&
        blobsRes.data.recoveryWrap != null &&
        blobsRes.data.recoveryLock != null;
  }

  /// Whether the recovery key can open this vault with its own password: a
  /// copy sealed to the recovery lock is kept.
  Future<bool> hasRecoveryCopy() async {
    final blobsRes = await chatAuthRepository.keyBlobs();
    return blobsRes is CryptoCoreSuccess<MasterKeyBlobs> &&
        blobsRes.data.vaultRecovery != null &&
        blobsRes.data.recoveryWrap != null;
  }

  /// Seals the key of the vault in [metadata] (its own password,
  /// [vaultPassword]) to [recoveryLock], for a new recovery key.
  Future<CryptoCoreResponse<Uint8List>> sealForRecovery({
    required String vaultPassword,
    required VaultMetadata metadata,
    required Uint8List recoveryLock,
  }) {
    return cryptoCoreService.vaultSealForRecovery(
      recoveryLock: recoveryLock,
      wrapped: base64Decode(metadata.verificationToken),
      vaultPassword: vaultPassword,
    );
  }

  /// The recovery key opens a vault with its own password: with
  /// [newPassword] the vault keeps its own password, now that one ("good" or
  /// better); without it the vault goes back under the master key. The
  /// answer is the unlocked key and the metadata to save; the recovery copy
  /// stays valid for a new own password and is dropped by the caller after a
  /// switch to the master password ([dropRecoveryCopy]).
  Future<VaultResponse<({VaultKey key, VaultMetadata metadata})>> recover({
    required String recoveryKey,
    required VaultMetadata metadata,
    String? newPassword,
  }) async {
    try {
      if (newPassword != null &&
          !passwordStrengthService.isStrongEnough(newPassword)) {
        return const VaultFailure(VaultFailureType.weakPassword);
      }
      final blobsRes = await chatAuthRepository.keyBlobs();
      if (blobsRes is CryptoCoreFailure<MasterKeyBlobs>) {
        return VaultFailure(
          _failureOf(blobsRes.type),
          message: blobsRes.type.name,
        );
      }
      final blobs = (blobsRes as CryptoCoreSuccess<MasterKeyBlobs>).data;
      final copy = blobs.vaultRecovery;
      final recoveryWrap = blobs.recoveryWrap;
      if (copy == null || recoveryWrap == null) {
        return const VaultFailure(VaultFailureType.noRecoveryKey);
      }
      final recoverRes = newPassword == null
          ? await cryptoCoreService.vaultRecoverToMaster(
              recoveryWrap: recoveryWrap,
              recovery: copy,
              recoveryKey: recoveryKey,
            )
          : await cryptoCoreService.vaultRecover(
              recovery: copy,
              recoveryKey: recoveryKey,
              newPassword: newPassword,
            );
      if (recoverRes is CryptoCoreFailure<CryptoCoreVaultInit>) {
        return VaultFailure(
          switch (recoverRes.type) {
            CryptoCoreFailureType.corrupt => VaultFailureType.recoveryKeyTypo,
            CryptoCoreFailureType.wrongPassword =>
              VaultFailureType.recoveryKeyWrong,
            _ => _failureOf(recoverRes.type),
          },
          message: recoverRes.type.name,
        );
      }
      final recovered =
          (recoverRes as CryptoCoreSuccess<CryptoCoreVaultInit>).data;
      return VaultSuccess(
        (
          key: recovered.key,
          metadata: metadata.copyWith(
            verificationToken: base64Encode(recovered.wrapped),
          ),
        ),
      );
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  /// The recovery lock the recovery key left (`null` without a recovery
  /// key).
  Future<VaultResponse<Uint8List?>> _recoveryLock() async {
    final blobsRes = await chatAuthRepository.keyBlobs();
    if (blobsRes is CryptoCoreFailure<MasterKeyBlobs>) {
      return VaultFailure(
        _failureOf(blobsRes.type),
        message: blobsRes.type.name,
      );
    }
    final blobs = (blobsRes as CryptoCoreSuccess<MasterKeyBlobs>).data;
    return VaultSuccess(blobs.recoveryWrap == null ? null : blobs.recoveryLock);
  }

  /// Keeps [copy] (or removes the copy with `null`); `null` on success.
  Future<VaultFailureType?> _saveRecoveryCopy(Uint8List? copy) async {
    final saveRes = await chatAuthRepository.saveVaultRecovery(copy);
    return saveRes is CryptoCoreFailure<void>
        ? VaultFailureType.storageWriteError
        : null;
  }

  VaultResponse<VaultMetadata> _withToken(
    CryptoCoreResponse<Uint8List> rewrapRes,
    VaultMetadata metadata,
  ) {
    if (rewrapRes is CryptoCoreFailure<Uint8List>) {
      return VaultFailure(
        _failureOf(rewrapRes.type),
        message: rewrapRes.type.name,
      );
    }
    final wrapped = (rewrapRes as CryptoCoreSuccess<Uint8List>).data;
    return VaultSuccess(
      metadata.copyWith(verificationToken: base64Encode(wrapped)),
    );
  }

  static VaultFailureType _failureOf(CryptoCoreFailureType type) {
    return switch (type) {
      CryptoCoreFailureType.wrongPassword =>
        VaultFailureType.incorrectMasterPassword,
      CryptoCoreFailureType.corrupt ||
      CryptoCoreFailureType.unsupportedFormat =>
        VaultFailureType.fileCorrupted,
      CryptoCoreFailureType.io => VaultFailureType.storageReadError,
      _ => VaultFailureType.unknown,
    };
  }

  /// Seals [content] as version [version] of the item [itemId]: the sealed
  /// bytes open only for that item at that version.
  Future<VaultResponse<Uint8List>> encryptContent(
    dynamic content,
    VaultKey masterKey, {
    required String itemId,
    required int version,
    String? customPassword,
  }) async {
    try {
      Uint8List bytesToEncrypt;

      if (content is VaultPasswordContent) {
        bytesToEncrypt = utf8.encode(jsonEncode(content.toJson()));
      } else if (content is VaultNoteContent) {
        bytesToEncrypt = utf8.encode(jsonEncode(content.toJson()));
      } else if (content is VaultFileContent) {
        bytesToEncrypt = utf8.encode(jsonEncode(content.toJson()));
      } else {
        return const VaultFailure(
          VaultFailureType.unknown,
          message: 'Unsupported content type',
        );
      }

      final sealRes = await cryptoCoreService.vaultSeal(
        key: masterKey,
        itemId: itemId,
        version: version,
        bytes: bytesToEncrypt,
      );
      if (sealRes is CryptoCoreFailure<Uint8List>) {
        return VaultFailure(
          VaultFailureType.unknown,
          message: sealRes.type.name,
        );
      }
      Uint8List encryptedBytes = (sealRes as CryptoCoreSuccess<Uint8List>).data;

      if (customPassword != null && customPassword.isNotEmpty) {
        final passwordRes = await cryptoCoreService.passwordSealBytes(
          password: customPassword,
          bytes: encryptedBytes,
        );
        if (passwordRes is CryptoCoreFailure<Uint8List>) {
          return VaultFailure(
            VaultFailureType.unknown,
            message: passwordRes.type.name,
          );
        }
        encryptedBytes = (passwordRes as CryptoCoreSuccess<Uint8List>).data;
      }

      return VaultSuccess(encryptedBytes);
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  /// Opens the item [itemId] at the [version] its index records, or one
  /// ahead of it (the app stopped between the file and the index write); an
  /// older copy, or another item's file, does not open.
  Future<VaultResponse<VaultDecryptedContent>> decryptContent(
    Uint8List encryptedBytes,
    VaultKey masterKey,
    VaultItemType type, {
    required String itemId,
    required int version,
    String? customPassword,
  }) async {
    try {
      Uint8List bytesToDecrypt = encryptedBytes;

      if (customPassword != null && customPassword.isNotEmpty) {
        final passwordRes = await cryptoCoreService.passwordOpenBytes(
          password: customPassword,
          blob: bytesToDecrypt,
        );
        if (passwordRes is CryptoCoreFailure<Uint8List>) {
          return VaultFailure(
            passwordRes.type == CryptoCoreFailureType.wrongPassword
                ? VaultFailureType.incorrectCustomPassword
                : VaultFailureType.decryptionFailed,
            message: passwordRes.type.name,
          );
        }
        bytesToDecrypt = (passwordRes as CryptoCoreSuccess<Uint8List>).data;
      }

      var openedVersion = version;
      var openRes = await cryptoCoreService.vaultOpen(
        key: masterKey,
        itemId: itemId,
        version: version,
        blob: bytesToDecrypt,
      );
      if (openRes is CryptoCoreFailure<Uint8List> &&
          openRes.type == CryptoCoreFailureType.corrupt) {
        openedVersion = version + 1;
        openRes = await cryptoCoreService.vaultOpen(
          key: masterKey,
          itemId: itemId,
          version: openedVersion,
          blob: bytesToDecrypt,
        );
      }
      if (openRes is CryptoCoreFailure<Uint8List>) {
        return VaultFailure(
          VaultFailureType.decryptionFailed,
          message: openRes.type.name,
        );
      }
      final decryptedBytes = (openRes as CryptoCoreSuccess<Uint8List>).data;

      final jsonString = utf8.decode(decryptedBytes);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

      VaultSuccess<VaultDecryptedContent> opened(dynamic content) =>
          VaultSuccess(
            VaultDecryptedContent(content: content, version: openedVersion),
          );

      if (type == VaultItemType.password) {
        return opened(VaultPasswordContent.fromJson(jsonMap));
      } else if (type == VaultItemType.note) {
        return opened(VaultNoteContent.fromJson(jsonMap));
      } else if (type == VaultItemType.file) {
        return opened(VaultFileContent.fromJson(jsonMap));
      } else {
        return const VaultFailure(
          VaultFailureType.unknown,
          message: 'Unsupported content type',
        );
      }
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }
}
