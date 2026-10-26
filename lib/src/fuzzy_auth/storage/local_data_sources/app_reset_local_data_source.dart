import 'dart:io';

import 'package:fuzzzy_ink/src/src.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as path;

/// Removes the app's own data from this device: the database, the core's
/// sealed chat states, the vault folder, the sealed files the app keeps
/// (chat and Basics containers), any hand-off or picker copy, every
/// preference (the remembered pairing replies included) and a link waiting
/// at the lock screen. Files the user saved or shared are the user's and are
/// never touched.
class AppResetLocalDataSource {
  AppResetLocalDataSource({required this.supportDirectoryPath});

  /// The core's store folder under the support directory
  /// (`STORE_SUBDIR` in `rust/fuzzy_crypto_core/src/store.rs`).
  static const storeFolderName = 'fuzzy_crypto_store';

  /// Left by an erase: the next launch opens the database compacted, so the
  /// pages the erase freed are gone from the file (security review
  /// 2026-10-26). The database stays open meanwhile: the first run that
  /// follows writes to it.
  static const compactMarkerName = '.compact_database';

  /// Whether the launch should compact the database, given the support
  /// directory; the marker is removed once the database is open.
  static File compactMarkerIn(String supportDirectoryPath) =>
      File(path.join(supportDirectoryPath, compactMarkerName));

  final String supportDirectoryPath;

  Future<void> clearDatabase() async {
    final isar = sl.get<Isar>();
    await isar.writeTxn(isar.clear);
    await compactMarkerIn(supportDirectoryPath).create(recursive: true);
  }

  /// Every preference, the remembered pairing replies included.
  Future<void> clearPreferences() async {
    if (sl.isRegistered<PreferencesService>()) {
      await sl.get<PreferencesService>().clearAll();
    }
    vaultPasswordCopySetting.value = true;
  }

  /// Plain copies the picker or a hand-off left in the app's folders.
  Future<void> wipePlainCopies() async {
    if (sl.isRegistered<UserFileStore>()) {
      await sl.get<UserFileStore>().wipeAtLock();
    }
  }

  /// A link waiting at the lock screen.
  void discardPendingLink() {
    if (sl.isRegistered<FuzzyLinkHandler>()) {
      sl.get<FuzzyLinkHandler>().discardPending();
    }
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
