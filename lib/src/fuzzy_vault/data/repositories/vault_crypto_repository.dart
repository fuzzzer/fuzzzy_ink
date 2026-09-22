import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fuzzzy_seal/lib.dart';

class VaultCryptoRepository {
  const VaultCryptoRepository({
    required this.passwordStrengthService,
    required this.cryptoCoreService,
  });

  final PasswordStrengthService passwordStrengthService;
  final CryptoCoreService cryptoCoreService;

  /// The master key never exists in Dart: the metadata keeps it wrapped under
  /// the password (`verificationToken`), and [unlock] hands back a handle.
  Future<VaultResponse<VaultMetadata>> initializeVault(String password) async {
    try {
      final strength = passwordStrengthService.assess(password);
      if (strength.level == PasswordStrengthLevel.weak) {
        return const VaultFailure(VaultFailureType.weakPassword);
      }

      final initRes = await cryptoCoreService.vaultInit(password);
      if (initRes is CryptoCoreFailure<CryptoCoreVaultInit>) {
        return VaultFailure(
          VaultFailureType.unknown,
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
        autoLockMinutes: 5,
      );

      return VaultSuccess(metadata);
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  Future<VaultResponse<VaultKey>> unlock(
    String password,
    VaultMetadata metadata,
  ) async {
    try {
      final keyRes = await cryptoCoreService.vaultUnlock(
        wrapped: base64Decode(metadata.verificationToken),
        password: password,
      );
      if (keyRes is CryptoCoreFailure<VaultKey>) {
        return VaultFailure(
          keyRes.type == CryptoCoreFailureType.wrongPassword
              ? VaultFailureType.incorrectMasterPassword
              : VaultFailureType.unknown,
          message: keyRes.type.name,
        );
      }
      return VaultSuccess((keyRes as CryptoCoreSuccess<VaultKey>).data);
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  /// A password change re-wraps the master key only — the key itself does not
  /// change, so no item is re-encrypted.
  Future<VaultResponse<VaultMetadata>> rewrap(
    String oldPassword,
    String newPassword,
    VaultMetadata metadata,
  ) async {
    try {
      final strength = passwordStrengthService.assess(newPassword);
      if (strength.level == PasswordStrengthLevel.weak) {
        return const VaultFailure(VaultFailureType.weakPassword);
      }

      final rewrapRes = await cryptoCoreService.vaultRewrap(
        wrapped: base64Decode(metadata.verificationToken),
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (rewrapRes is CryptoCoreFailure<Uint8List>) {
        return VaultFailure(
          rewrapRes.type == CryptoCoreFailureType.wrongPassword
              ? VaultFailureType.incorrectMasterPassword
              : VaultFailureType.unknown,
          message: rewrapRes.type.name,
        );
      }
      final wrapped = (rewrapRes as CryptoCoreSuccess<Uint8List>).data;

      return VaultSuccess(
        metadata.copyWith(verificationToken: base64Encode(wrapped)),
      );
    } catch (e) {
      return VaultFailure(VaultFailureType.unknown, message: e.toString());
    }
  }

  Future<VaultResponse<Uint8List>> encryptContent(
    dynamic content,
    VaultKey masterKey, {
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

  Future<VaultResponse<dynamic>> decryptContent(
    Uint8List encryptedBytes,
    VaultKey masterKey,
    VaultItemType type, {
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

      final openRes = await cryptoCoreService.vaultOpen(
        key: masterKey,
        blob: bytesToDecrypt,
      );
      if (openRes is CryptoCoreFailure<Uint8List>) {
        return VaultFailure(
          VaultFailureType.decryptionFailed,
          message: openRes.type.name,
        );
      }
      final decryptedBytes = (openRes as CryptoCoreSuccess<Uint8List>).data;

      final jsonString = utf8.decode(decryptedBytes);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

      if (type == VaultItemType.password) {
        return VaultSuccess(VaultPasswordContent.fromJson(jsonMap));
      } else if (type == VaultItemType.note) {
        return VaultSuccess(VaultNoteContent.fromJson(jsonMap));
      } else if (type == VaultItemType.file) {
        return VaultSuccess(VaultFileContent.fromJson(jsonMap));
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
