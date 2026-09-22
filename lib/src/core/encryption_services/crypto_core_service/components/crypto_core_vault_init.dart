import 'dart:typed_data';

import 'package:fuzzzy_seal/lib.dart';

/// A vault that was just created: the unlocked master-key handle for this
/// session and its wrapping (a 0x10 blob under the vault password), which the
/// metadata stores and a later unlock unwraps.
class CryptoCoreVaultInit {
  final VaultKey key;
  final Uint8List wrapped;

  const CryptoCoreVaultInit({
    required this.key,
    required this.wrapped,
  });
}
