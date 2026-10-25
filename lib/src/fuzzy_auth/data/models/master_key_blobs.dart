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

  const MasterKeyBlobs({
    required this.passwordWrap,
    required this.storeWrap,
    this.recoveryWrap,
  });
}
