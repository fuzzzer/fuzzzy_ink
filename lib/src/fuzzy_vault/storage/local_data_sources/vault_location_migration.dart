import 'dart:convert';
import 'dart:io';

import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

enum VaultLocationMigrationResult {
  /// No vault in the documents directory, and no move to resume.
  nothingToMove,

  /// The vault now lives in its private folder only.
  moved,

  /// Both places hold a vault; the private one is kept and the old one is
  /// left untouched.
  keptExisting,

  /// The move stopped on an error; the marker stays, the vault stays closed
  /// and the next start resumes.
  failed,
}

/// Moves a vault that older builds kept loose in the documents directory
/// (`vault.meta`, `items/*.vault`, `.tmp/`, `.tmp_export/`) into its private
/// folder ([VaultFileDataSource.directoryIn] the app support directory).
///
/// Crash-safe: a marker is written in the new folder before anything moves,
/// and every file exists whole in at least one place at every moment (rename,
/// or copy → flush → size check → rename → delete the old one). `vault.meta`
/// moves last. While the marker exists [VaultFileDataSource] refuses to open
/// or write the vault, and the next [run] resumes. Only files the vault itself
/// wrote are moved or deleted; anything else in the documents directory — a
/// foreign `items/` file included — stays.
class VaultLocationMigration {
  const VaultLocationMigration({
    required this.legacyDirectoryPath,
    required this.vaultDataSource,
    this.preferRename = true,
  });

  /// The directory older builds used as the vault folder (app documents).
  final String legacyDirectoryPath;

  /// The data source of the new, private vault folder.
  final VaultFileDataSource vaultDataSource;

  /// `false` forces the copy path a move across volumes takes (tests).
  final bool preferRename;

  static const _maxMetaBytes = 64 * 1024;
  static const _blobMagic = [0x46, 0x55, 0x5a, 0x5a]; // "FUZZ"
  static const _copySuffix = '.migrating';

  String get _vaultPath => vaultDataSource.vaultDirectoryPath;

  /// Never throws: a failure is logged and reported as
  /// [VaultLocationMigrationResult.failed].
  Future<VaultLocationMigrationResult> run() async {
    try {
      return await _run();
    } catch (error, stackTrace) {
      logger.e(
        'VAULT MIGRATION: stopped, resumes at the next start',
        error: error,
        stackTrace: stackTrace,
      );
      return VaultLocationMigrationResult.failed;
    }
  }

  Future<VaultLocationMigrationResult> _run() async {
    if (path.equals(
      path.normalize(path.absolute(legacyDirectoryPath)),
      path.normalize(path.absolute(_vaultPath)),
    )) {
      return VaultLocationMigrationResult.nothingToMove;
    }

    final marker = File(
      path.join(_vaultPath, VaultFileDataSource.migrationMarkerName),
    );
    final legacyMeta = File(
      path.join(legacyDirectoryPath, VaultFileDataSource.metaFileName),
    );
    final newMeta =
        File(path.join(_vaultPath, VaultFileDataSource.metaFileName));

    if (!await marker.exists()) {
      if (!await _isVaultMeta(legacyMeta)) {
        return VaultLocationMigrationResult.nothingToMove;
      }
      if (await newMeta.exists()) {
        logger.w(
          'VAULT MIGRATION: a vault already exists in the private folder; '
          'the one in the documents directory is left untouched',
        );
        return VaultLocationMigrationResult.keptExisting;
      }
      await vaultDataSource.initDirectories();
      await marker.writeAsString('', flush: true);
    } else {
      await vaultDataSource.initDirectories();
    }

    await _moveItems();
    if (await _isVaultMeta(legacyMeta)) {
      await _move(legacyMeta, newMeta);
    }
    await _removeLegacyLeftovers();
    await _removeStaleCopies();

    await marker.delete();
    logger.i('VAULT MIGRATION: vault moved to its private folder');
    return VaultLocationMigrationResult.moved;
  }

  Future<void> _moveItems() async {
    final legacyItems = Directory(
      path.join(legacyDirectoryPath, VaultFileDataSource.itemsFolderName),
    );
    if (!await legacyItems.exists()) return;
    final newItemsPath =
        path.join(_vaultPath, VaultFileDataSource.itemsFolderName);
    final entities = await legacyItems.list(followLinks: false).toList();
    for (final entity in entities) {
      if (entity is! File) continue;
      final name = path.basename(entity.path);
      if (!_isItemFileName(name)) continue;
      if (!await _startsWithBlobMagic(entity)) continue;
      await _move(entity, File(path.join(newItemsPath, name)));
    }
  }

  /// Moves [source] to [target] so that a whole copy exists at every moment.
  Future<void> _move(File source, File target) async {
    if (await target.exists()) {
      // Only a finished copy is ever renamed into place, so an existing target
      // is whole: the earlier run stopped before deleting the source.
      if (await target.length() == await source.length()) {
        await source.delete();
      } else {
        logger.w(
          'VAULT MIGRATION: ${path.basename(target.path)} differs from the '
          'older copy; both are kept',
        );
      }
      return;
    }

    if (preferRename) {
      try {
        await source.rename(target.path);
        return;
      } on FileSystemException {
        // Another volume: copy instead.
      }
    }

    final copy = File(
      path.join(
        _vaultPath,
        VaultFileDataSource.tmpFolderName,
        '${path.basename(target.path)}$_copySuffix',
      ),
    );
    await source.copy(copy.path);
    final handle = await copy.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await copy.length() != await source.length()) {
      await copy.delete();
      throw FileSystemException('copy is incomplete', source.path);
    }
    await copy.rename(target.path);
    await source.delete();
  }

  /// Deletes only what the vault itself wrote in the documents directory, and
  /// each folder only once it is empty.
  Future<void> _removeLegacyLeftovers() async {
    final legacyTmp = Directory(
      path.join(legacyDirectoryPath, VaultFileDataSource.tmpFolderName),
    );
    if (await legacyTmp.exists()) {
      final entities = await legacyTmp.list(followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File && _isVaultTmpFileName(path.basename(entity.path))) {
          await entity.delete();
        }
      }
    }
    for (final folderName in [
      VaultFileDataSource.tmpFolderName,
      VaultFileDataSource.exportTmpFolderName,
      VaultFileDataSource.itemsFolderName,
    ]) {
      await _deleteIfEmpty(
        Directory(path.join(legacyDirectoryPath, folderName)),
      );
    }
  }

  Future<void> _removeStaleCopies() async {
    final tmp =
        Directory(path.join(_vaultPath, VaultFileDataSource.tmpFolderName));
    if (!await tmp.exists()) return;
    final entities = await tmp.list(followLinks: false).toList();
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith(_copySuffix)) {
        await entity.delete();
      }
    }
  }

  Future<void> _deleteIfEmpty(Directory directory) async {
    if (!await directory.exists()) return;
    if (!await directory.list(followLinks: false).isEmpty) return;
    await directory.delete();
  }

  bool _isItemFileName(String name) =>
      name.length > VaultFileDataSource.itemFileExtension.length &&
      name.endsWith(VaultFileDataSource.itemFileExtension);

  bool _isVaultTmpFileName(String name) =>
      name == '${VaultFileDataSource.metaFileName}.tmp' ||
      (name.endsWith('${VaultFileDataSource.itemFileExtension}.tmp') &&
          _isItemFileName(name.substring(0, name.length - '.tmp'.length)));

  Future<bool> _startsWithBlobMagic(File file) async {
    final head = <int>[];
    await for (final chunk in file.openRead(0, _blobMagic.length)) {
      head.addAll(chunk);
    }
    if (head.length != _blobMagic.length) return false;
    for (var index = 0; index < _blobMagic.length; index++) {
      if (head[index] != _blobMagic[index]) return false;
    }
    return true;
  }

  /// Whether [file] is the vault's own `vault.meta` (a JSON object with the
  /// vault id and the wrapped key), not some other file of that name.
  Future<bool> _isVaultMeta(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    if (await file.length() > _maxMetaBytes) return false;
    try {
      final decoded = jsonDecode(utf8.decode(await file.readAsBytes()));
      return decoded is Map<String, dynamic> &&
          decoded['vaultId'] is String &&
          decoded['verificationToken'] is String;
    } on FormatException {
      return false;
    }
  }
}
