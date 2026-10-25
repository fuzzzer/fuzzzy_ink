import 'dart:typed_data';

/// A new printable recovery key and the master key's wrap under it.
class CryptoCoreRecoveryKey {
  final String recoveryKey;
  final Uint8List recoveryWrap;

  const CryptoCoreRecoveryKey({
    required this.recoveryKey,
    required this.recoveryWrap,
  });
}
