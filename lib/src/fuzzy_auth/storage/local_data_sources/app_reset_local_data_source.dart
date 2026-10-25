import 'dart:io';

import 'package:fuzzzy_ink/src/src.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as path;

/// Removes the app's own data from this device: the database, the core's
/// sealed chat states and the vault folder. Files the user unfuzzed are the
/// user's and are never touched.
class AppResetLocalDataSource {
  AppResetLocalDataSource({required this.supportDirectoryPath});

  /// The core's store folder under the support directory
  /// (`STORE_SUBDIR` in `rust/fuzzy_crypto_core/src/store.rs`).
  static const storeFolderName = 'fuzzy_crypto_store';

  final String supportDirectoryPath;

  Future<void> clearDatabase() async {
    final isar = sl.get<Isar>();
    await isar.writeTxn(isar.clear);
  }

  Future<void> deleteChatStates() async {
    final store = Directory(path.join(supportDirectoryPath, storeFolderName));
    if (await store.exists()) await store.delete(recursive: true);
  }

  Future<void> deleteVault() => sl.get<VaultFileDataSource>().clearAll();
}
