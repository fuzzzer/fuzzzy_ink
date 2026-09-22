import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:fuzzzy_ink/rust_bridge/frb_generated.dart';

bool _initialized = false;

/// Loads the Rust crypto core for `flutter test`.
///
/// The generated default loader path is not used here on purpose: tests load
/// the library built by `cargo build --release --manifest-path
/// rust/fuzzy_crypto_core/Cargo.toml` explicitly (see plan §A.1, pitfall §F.4).
Future<void> initCryptoCoreForTests() async {
  if (_initialized) return;

  final extension = Platform.isMacOS ? 'dylib' : 'so';
  final libraryPath =
      'rust/fuzzy_crypto_core/target/release/libfuzzy_crypto_core.$extension';

  await FuzzyCryptoCoreLib.init(
    externalLibrary: ExternalLibrary.open(libraryPath),
  );
  _initialized = true;
}
