import 'dart:typed_data';

import 'package:fuzzzy_ink/lib.dart';

/// A vault that was just created, or opened by the recovery key: the
/// unlocked vault-key handle for this session and its wrapping (a 0x20 blob
/// under the master key, or a 0x10 under the vault's own password), which the
/// metadata stores and a later unlock unwraps. A new vault with its own
/// password also carries [recovery]: its key sealed to the recovery lock
/// (0x11), when a recovery key is kept.
class CryptoCoreVaultInit {
  final VaultKey key;
  final Uint8List wrapped;
  final Uint8List? recovery;

  const CryptoCoreVaultInit({
    required this.key,
    required this.wrapped,
    this.recovery,
  });
}
