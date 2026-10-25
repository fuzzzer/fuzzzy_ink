import 'dart:io';

import 'package:fuzzzy_ink/src/src.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as path;

/// Removes the app's own data from this device: the database, the core's
/// sealed chat states, the vault folder, the sealed files the app keeps
/// (chat and Basics containers) and any hand-off copy. Files the user saved
/// or shared are the user's and are never touched.
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

  /// The kept chat and Basics containers (`UserFileStore`'s `sealed_files/`)
  /// and the hand-off folder of plain copies in use.
  Future<void> deleteSealedFiles() async {
    for (final folderName in [
      UserFileStore.sealedFolderName,
      UserFileStore.handoffFolderName,
    ]) {
      final folder = Directory(path.join(supportDirectoryPath, folderName));
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  }
}
