import 'dart:typed_data';

/// A new printable recovery key, the master key's wrap under it and its
/// lock (the public half, sealed under the store key) that a vault with its
/// own password is sealed to.
class CryptoCoreRecoveryKey {
  final String recoveryKey;
  final Uint8List recoveryWrap;
  final Uint8List recoveryLock;

  const CryptoCoreRecoveryKey({
    required this.recoveryKey,
    required this.recoveryWrap,
    required this.recoveryLock,
  });
}
