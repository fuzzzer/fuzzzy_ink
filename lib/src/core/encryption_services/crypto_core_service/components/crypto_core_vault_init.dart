import 'dart:typed_data';

import 'package:fuzzzy_ink/lib.dart';

/// A vault that was just created (always under the master key), or opened
/// by the recovery key: the unlocked vault-key handle for this session and
/// its wrapping (a 0x20 blob under the master key, or a 0x10 under the
/// vault's own password), which the metadata stores and a later unlock
/// unwraps.
class CryptoCoreVaultInit {
  final VaultKey key;
  final Uint8List wrapped;

  const CryptoCoreVaultInit({
    required this.key,
    required this.wrapped,
  });
}
