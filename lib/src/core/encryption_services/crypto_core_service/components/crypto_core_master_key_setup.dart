import 'dart:typed_data';

/// What the first run leaves behind: the master key wrapped under the master
/// password and under the recovery key (0x10 blobs), the store key wrapped
/// under the master key (0x20), and the recovery key to show the user once.
/// The store is already open.
class CryptoCoreMasterKeySetup {
  final Uint8List passwordWrap;
  final Uint8List recoveryWrap;
  final Uint8List storeWrap;
  final String recoveryKey;

  const CryptoCoreMasterKeySetup({
    required this.passwordWrap,
    required this.recoveryWrap,
    required this.storeWrap,
    required this.recoveryKey,
  });
}
