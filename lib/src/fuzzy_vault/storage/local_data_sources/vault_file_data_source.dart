import 'dart:io';

import 'package:fuzzzy_ink/lib.dart';
import 'package:path/path.dart' as path;

/// Thrown while the vault cannot be used because its move from the documents
/// directory is unfinished ([VaultFileDataSource.moveFailed] or the
/// migration marker).
class VaultMoveUnfinishedException extends FileSystemException {
  const VaultMoveUnfinishedException(String path)
      : super(
          'The vault is still being moved to its private folder; '
          'the move resumes at the next start',
          path,
        );
}

class VaultFileDataSource {
  const VaultFileDataSource({
    required this.vaultDirectoryPath,
    this.backupExclusion = const BackupExclusion(),
    this.moveFailed = false,
  });

  /// The vault's own folder inside the app-private support directory. Only a
  /// folder with this name can be wiped by [clearAll].
  static const folderName = 'vault';

  /// Kept in the vault folder while [VaultLocationMigration] moves a vault
  /// from the documents directory; while it exists the vault neither opens
  /// nor accepts writes, so a half-moved vault is never replaced.
  static const migrationMarkerName = '.migration_in_progress';

  static const metaFileName = 'vault.meta';
  static const itemsFolderName = 'items';
  static const tmpFolderName = '.tmp';
  static const exportTmpFolderName = '.tmp_export';
  static const itemFileExtension = '.vault';

  /// An item's list label (its username or file name), sealed on its own
  /// beside the item so My safe's list never opens the item itself
  /// (`VaultRepository.readLabels`).
  static const labelFileExtension = '.label';

  /// A new key's copies while the vault moves to it ([beginRekey]): the new
  /// `vault.meta` beside the old one, each re-sealed item beside its old
  /// file.
  static const rekeySuffix = '.rekey';

  /// The vault folder under [parentDirectoryPath] (the app support directory).
  static String directoryIn(String parentDirectoryPath) =>
      path.join(parentDirectoryPath, folderName);

  final String vaultDirectoryPath;

  /// The vault's folders are kept out of iCloud / Time Machine (T-0432).
  final BackupExclusion backupExclusion;

  /// The move at this start stopped before its marker was written (an
  /// unreadable old `vault.meta`, say). The vault then neither opens nor
  /// accepts writes, so no new vault is made beside the one still in the
  /// documents directory; the next start tries the move again.
  final bool moveFailed;

  Directory get _vaultDir => Directory(vaultDirectoryPath);
  Directory get _itemsDir =>
      Directory(path.join(vaultDirectoryPath, itemsFolderName));
  Directory get _tmpDir =>
      Directory(path.join(vaultDirectoryPath, tmpFolderName));
  File get _metaFile => File(path.join(vaultDirectoryPath, metaFileName));
  File get _stagedMetaFile =>
      File(path.join(vaultDirectoryPath, '$metaFileName$rekeySuffix'));
  File get _migrationMarker =>
      File(path.join(vaultDirectoryPath, migrationMarkerName));

  /// Working folder of the vault export, inside the vault folder.
  String get exportTmpDirectoryPath =>
      path.join(vaultDirectoryPath, exportTmpFolderName);

  Future<void> initDirectories() async {
    for (final directory in [_vaultDir, _itemsDir, _tmpDir]) {
      if (await directory.exists()) continue;
      await directory.create(recursive: true);
      await backupExclusion.exclude(directory.path);
    }
  }

  Future<void> _ensureNotMigrating() async {
    if (moveFailed || await _migrationMarker.exists()) {
      throw VaultMoveUnfinishedException(vaultDirectoryPath);
    }
  }

  Future<void> writeMetaAtomic(List<int> bytes) async {
    await _ensureNotMigrating();
    await initDirectories();
    final tmpFile = File(path.join(_tmpDir.path, '$metaFileName.tmp'));
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(_metaFile.path);
  }

  Future<List<int>?> readMeta() async {
    await _ensureNotMigrating();
    await finishInterruptedRekey();
    if (!await _metaFile.exists()) return null;
    return await _metaFile.readAsBytes();
  }

  Future<void> writeItemAtomic(String itemId, List<int> bytes) async {
    await _ensureNotMigrating();
    await initDirectories();
    final tmpFile =
        File(path.join(_tmpDir.path, '$itemId$itemFileExtension.tmp'));
    await tmpFile.writeAsBytes(bytes, flush: true);
    final itemFile =
        File(path.join(_itemsDir.path, '$itemId$itemFileExtension'));
    await tmpFile.rename(itemFile.path);
  }

  Future<List<int>?> readItem(String itemId) async {
    final itemFile =
        File(path.join(_itemsDir.path, '$itemId$itemFileExtension'));
    if (!await itemFile.exists()) return null;
    return await itemFile.readAsBytes();
  }

  Future<void> deleteItem(String itemId) async {
    await _ensureNotMigrating();
    final itemFile =
        File(path.join(_itemsDir.path, '$itemId$itemFileExtension'));
    if (await itemFile.exists()) {
      await itemFile.delete();
    }
    await deleteLabel(itemId);
  }

  File _labelFile(String itemId) =>
      File(path.join(_itemsDir.path, '$itemId$labelFileExtension'));

  Future<void> writeLabelAtomic(String itemId, List<int> bytes) async {
    await _ensureNotMigrating();
    await initDirectories();
    final tmpFile =
        File(path.join(_tmpDir.path, '$itemId$labelFileExtension.tmp'));
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(_labelFile(itemId).path);
  }

  Future<List<int>?> readLabel(String itemId) async {
    final labelFile = _labelFile(itemId);
    if (!await labelFile.exists()) return null;
    return await labelFile.readAsBytes();
  }

  Future<void> deleteLabel(String itemId) async {
    final labelFile = _labelFile(itemId);
    if (await labelFile.exists()) await labelFile.delete();
  }

  /// Starts moving the vault to a new key (its own password, security review
  /// 2026-10-26): the new `vault.meta` is written beside the old one first,
  /// so its presence says "not committed yet" — a stop before [commitRekey]
  /// is rolled back, a stop after it rolled forward ([finishInterruptedRekey]).
  Future<void> beginRekey(List<int> metaBytes) async {
    await _ensureNotMigrating();
    await initDirectories();
    await abandonRekey();
    final tmpFile =
        File(path.join(_tmpDir.path, '$metaFileName$rekeySuffix.tmp'));
    await tmpFile.writeAsBytes(metaBytes, flush: true);
    await tmpFile.rename(_stagedMetaFile.path);
  }

  /// One item re-sealed under the new key, beside its old file.
  Future<void> stageRekeyedItem(String itemId, List<int> bytes) async {
    await _ensureNotMigrating();
    final tmpFile = File(
      path.join(_tmpDir.path, '$itemId$itemFileExtension$rekeySuffix.tmp'),
    );
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(_stagedItem(itemId).path);
  }

  /// One item's label re-sealed under the new key, beside its old file.
  Future<void> stageRekeyedLabel(String itemId, List<int> bytes) async {
    await _ensureNotMigrating();
    final tmpFile = File(
      path.join(_tmpDir.path, '$itemId$labelFileExtension$rekeySuffix.tmp'),
    );
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename('${_labelFile(itemId).path}$rekeySuffix');
  }

  /// The commit: one rename puts the new `vault.meta` in place; then every
  /// staged item replaces its old file. From here the old key opens nothing.
  Future<void> commitRekey() async {
    await _ensureNotMigrating();
    await _stagedMetaFile.rename(_metaFile.path);
    await _rollRekeyForward();
  }

  /// Drops a key change that was not committed: the staged items first, the
  /// staged `vault.meta` last (while it exists a later start rolls back too).
  Future<void> abandonRekey() async {
    for (final staged in await _stagedItems()) {
      await staged.delete();
    }
    if (await _stagedMetaFile.exists()) await _stagedMetaFile.delete();
  }

  /// After a stop during a key change: before the commit (the staged
  /// `vault.meta` is still there) the old vault stays and the copies go;
  /// after it the staged items replace the old ones. `true` when the vault
  /// is on the new key (or no change was under way), `false` after a roll
  /// back.
  Future<bool> finishInterruptedRekey() async {
    if (await _stagedMetaFile.exists()) {
      await abandonRekey();
      return false;
    }
    await _rollRekeyForward();
    return true;
  }

  Future<void> _rollRekeyForward() async {
    for (final staged in await _stagedItems()) {
      final name = path.basename(staged.path);
      await staged.rename(
        path.join(
          _itemsDir.path,
          name.substring(0, name.length - rekeySuffix.length),
        ),
      );
    }
  }

  File _stagedItem(String itemId) => File(
        path.join(_itemsDir.path, '$itemId$itemFileExtension$rekeySuffix'),
      );

  Future<List<File>> _stagedItems() async {
    if (!await _itemsDir.exists()) return const [];
    return [
      await for (final entity in _itemsDir.list())
        if (entity is File &&
            (entity.path.endsWith('$itemFileExtension$rekeySuffix') ||
                entity.path.endsWith('$labelFileExtension$rekeySuffix')))
          entity,
    ];
  }

  /// Deletes the vault folder and everything in it. Refuses any folder not
  /// named [folderName], so a misconfigured path can never wipe the documents
  /// directory or another parent folder.
  Future<void> clearAll() async {
    final normalizedPath = path.normalize(path.absolute(vaultDirectoryPath));
    if (path.basename(normalizedPath) != folderName) {
      throw StateError(
        'clearAll refuses to delete $normalizedPath: not the vault folder',
      );
    }
    final vaultDir = Directory(normalizedPath);
    if (await vaultDir.exists()) {
      await vaultDir.delete(recursive: true);
    }
  }
}
