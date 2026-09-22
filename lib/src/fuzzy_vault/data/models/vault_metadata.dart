import '../../storage/storage_models/stored_vault_metadata.dart';

class VaultMetadata {
  const VaultMetadata({
    required this.vaultId,
    required this.verificationToken,
    required this.createdAt,
    required this.lastUnlockedAt,
    required this.autoLockMinutes,
    this.customDirectoryPath,
  });

  final String vaultId;
  final String verificationToken;
  final DateTime createdAt;
  final DateTime lastUnlockedAt;
  final int autoLockMinutes;
  final String? customDirectoryPath;

  factory VaultMetadata.fromStored(StoredVaultMetadata stored) {
    return VaultMetadata(
      vaultId: stored.vaultId,
      verificationToken: stored.verificationTokenBase64,
      createdAt: stored.createdAt,
      lastUnlockedAt: stored.lastUnlockedAt,
      autoLockMinutes: stored.autoLockMinutes,
      customDirectoryPath: stored.customDirectoryPath,
    );
  }

  VaultMetadata copyWith({
    String? vaultId,
    String? verificationToken,
    DateTime? createdAt,
    DateTime? lastUnlockedAt,
    int? autoLockMinutes,
    String? customDirectoryPath,
  }) {
    return VaultMetadata(
      vaultId: vaultId ?? this.vaultId,
      verificationToken: verificationToken ?? this.verificationToken,
      createdAt: createdAt ?? this.createdAt,
      lastUnlockedAt: lastUnlockedAt ?? this.lastUnlockedAt,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      customDirectoryPath: customDirectoryPath ?? this.customDirectoryPath,
    );
  }
}
