import 'dart:typed_data';

/// The master key's blobs as the secure storage keeps them: only wrapped
/// forms, never a key.
class MasterKeyBlobs {
  /// 0x10 — the master key under the master password.
  final Uint8List passwordWrap;

  /// 0x20 — the store key under the master key.
  final Uint8List storeWrap;

  /// 0x10 — the master key under the recovery key; `null` when the user
  /// chose to go without one.
  final Uint8List? recoveryWrap;

  /// 0x20 — the recovery lock (public) under the store key, kept with the
  /// recovery wrap: what a vault with its own password is sealed to.
  final Uint8List? recoveryLock;

  /// 0x11 — the key of a vault with its own password sealed to the recovery
  /// lock, so the recovery key opens that vault; `null` otherwise.
  final Uint8List? vaultRecovery;

  const MasterKeyBlobs({
    required this.passwordWrap,
    required this.storeWrap,
    this.recoveryWrap,
    this.recoveryLock,
    this.vaultRecovery,
  });
}
