import '../../storage/storage_models/stored_vault_metadata.dart';

class VaultMetadata {
  const VaultMetadata({
    required this.vaultId,
    required this.verificationToken,
    required this.createdAt,
    required this.lastUnlockedAt,
    this.customDirectoryPath,
  });

  final String vaultId;

  /// base64 of the wrapped vault key: a 0x20 under the master key, or a 0x10
  /// under the vault's own password (the type byte tells which).
  final String verificationToken;
  final DateTime createdAt;
  final DateTime lastUnlockedAt;
  final String? customDirectoryPath;

  factory VaultMetadata.fromStored(StoredVaultMetadata stored) {
    return VaultMetadata(
      vaultId: stored.vaultId,
      verificationToken: stored.verificationTokenBase64,
      createdAt: stored.createdAt,
      lastUnlockedAt: stored.lastUnlockedAt,
      customDirectoryPath: stored.customDirectoryPath,
    );
  }

  VaultMetadata copyWith({
    String? vaultId,
    String? verificationToken,
    DateTime? createdAt,
    DateTime? lastUnlockedAt,
    String? customDirectoryPath,
  }) {
    return VaultMetadata(
      vaultId: vaultId ?? this.vaultId,
      verificationToken: verificationToken ?? this.verificationToken,
      createdAt: createdAt ?? this.createdAt,
      lastUnlockedAt: lastUnlockedAt ?? this.lastUnlockedAt,
      customDirectoryPath: customDirectoryPath ?? this.customDirectoryPath,
    );
  }
}
