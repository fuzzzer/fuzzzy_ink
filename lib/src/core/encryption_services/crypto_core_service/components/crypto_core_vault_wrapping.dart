import 'dart:typed_data';

/// A vault key's new wrapping after it gets its own password: [wrapped] (a
/// 0x10 under that password) and, when a recovery key is kept, [recovery]
/// (the key sealed to the recovery lock, a 0x11), so the recovery key still
/// opens the vault.
class CryptoCoreVaultWrapping {
  final Uint8List wrapped;
  final Uint8List? recovery;

  const CryptoCoreVaultWrapping({
    required this.wrapped,
    this.recovery,
  });
}
