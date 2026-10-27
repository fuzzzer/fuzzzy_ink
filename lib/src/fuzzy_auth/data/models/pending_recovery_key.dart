import 'dart:typed_data';

/// A new recovery key on screen until the user confirms saving it: the key
/// text, the master key's wrap under it, its lock (under the store key) and,
/// for a vault with its own password, the vault key sealed to that lock.
/// Nothing here is stored until the confirmation.
class PendingRecoveryKey {
  final String recoveryKey;
  final Uint8List recoveryWrap;
  final Uint8List recoveryLock;
  final Uint8List? vaultRecovery;

  const PendingRecoveryKey({
    required this.recoveryKey,
    required this.recoveryWrap,
    required this.recoveryLock,
    this.vaultRecovery,
  });
}
