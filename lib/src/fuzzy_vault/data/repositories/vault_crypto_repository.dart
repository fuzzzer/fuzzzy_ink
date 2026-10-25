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
  /// key needs to open.
  final ChatAuthRepository chatAuthRepository;

  /// The vault key never exists in Dart: the metadata keeps it wrapped
  /// (`verificationToken`), and [unlock] hands back a handle. By default the
  /// master key wraps it, so [password] is the master password; with
  /// [ownPassword] the vault gets [password] as its own ("good" or better).
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
        initRes = await cryptoCoreService.vaultInit(password);
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
      final rewrapRes = await cryptoCoreService.vaultUseOwnPassword(
        passwordWrap: (wrapRes as CryptoCoreSuccess<Uint8List>).data,
        masterPassword: masterPassword,
        wrapped: base64Decode(metadata.verificationToken),
        newPassword: newPassword,
      );
      return _withToken(rewrapRes, metadata);
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
