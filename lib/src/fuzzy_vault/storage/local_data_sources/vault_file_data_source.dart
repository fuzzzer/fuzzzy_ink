import 'dart:io';

import 'package:fuzzzy_ink/lib.dart';
import 'package:path/path.dart' as path;

class VaultFileDataSource {
  const VaultFileDataSource({
    required this.vaultDirectoryPath,
    this.backupExclusion = const BackupExclusion(),
  });
  final String vaultDirectoryPath;

  /// The vault's folders are kept out of iCloud / Time Machine (T-0432).
  final BackupExclusion backupExclusion;

  Directory get _vaultDir => Directory(vaultDirectoryPath);
  Directory get _itemsDir => Directory(path.join(vaultDirectoryPath, 'items'));
  Directory get _tmpDir => Directory(path.join(vaultDirectoryPath, '.tmp'));
  File get _metaFile => File(path.join(vaultDirectoryPath, 'vault.meta'));

  Future<void> initDirectories() async {
    for (final directory in [_vaultDir, _itemsDir, _tmpDir]) {
      if (await directory.exists()) continue;
      await directory.create(recursive: true);
      await backupExclusion.exclude(directory.path);
    }
  }

  Future<void> writeMetaAtomic(List<int> bytes) async {
    await initDirectories();
    final tmpFile = File(path.join(_tmpDir.path, 'vault.meta.tmp'));
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(_metaFile.path);
  }

  Future<List<int>?> readMeta() async {
    if (!await _metaFile.exists()) return null;
    return await _metaFile.readAsBytes();
  }

  Future<void> writeItemAtomic(String itemId, List<int> bytes) async {
    await initDirectories();
    final tmpFile = File(path.join(_tmpDir.path, '$itemId.vault.tmp'));
    await tmpFile.writeAsBytes(bytes, flush: true);
    final itemFile = File(path.join(_itemsDir.path, '$itemId.vault'));
    await tmpFile.rename(itemFile.path);
  }

  Future<List<int>?> readItem(String itemId) async {
    final itemFile = File(path.join(_itemsDir.path, '$itemId.vault'));
    if (!await itemFile.exists()) return null;
    return await itemFile.readAsBytes();
  }

  Future<void> deleteItem(String itemId) async {
    final itemFile = File(path.join(_itemsDir.path, '$itemId.vault'));
    if (await itemFile.exists()) {
      await itemFile.delete();
    }
  }

  Future<void> clearAll() async {
    if (await _vaultDir.exists()) {
      await _vaultDir.delete(recursive: true);
    }
  }
}
