import 'dart:typed_data';

import 'package:fuzzzy_ink/lib.dart';

/// A vault that gets its own password gets a new key and a new recovery key
/// in the same step (security review 2026-10-26): [previous] is the key every
/// item is re-sealed from, [key] the new one, [wrapped] the new key under the
/// new password (0x10). [recovery] is the new recovery key with the master
/// key's wrap under it, its lock, and the new vault key sealed to that lock
/// (its `vaultRecovery`, 0x11) — kept only once the user confirms saving it.
class CryptoCoreVaultOwnPassword {
  final VaultKey previous;
  final VaultKey key;
  final Uint8List wrapped;
  final CryptoCoreRecoveryKey recovery;
  final Uint8List vaultRecovery;

  const CryptoCoreVaultOwnPassword({
    required this.previous,
    required this.key,
    required this.wrapped,
    required this.recovery,
    required this.vaultRecovery,
  });
}
