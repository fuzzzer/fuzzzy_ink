import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fuzzzy_ink/lib.dart';

class VaultRepository {
  const VaultRepository({
    required this.itemDataSource,
    required this.groupDataSource,
    required this.fileDataSource,
    required this.cryptoRepository,
  });

  final VaultItemLocalDataSource itemDataSource;
  final VaultGroupLocalDataSource groupDataSource;
  final VaultFileDataSource fileDataSource;
  final VaultCryptoRepository cryptoRepository;

  Stream<VaultDataUpdated> get vaultDataUpdates =>
      fuzzyHub.on<VaultDataUpdated>();

  Future<VaultResponse<VaultMetadata>> getMetadata() async {
    try {
      final bytes = await fileDataSource.readMeta();
      if (bytes == null) {
        return const VaultFailure(VaultFailureType.vaultNotInitialized);
      }
      final jsonString = utf8.decode(bytes);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

      return VaultSuccess(
        VaultMetadata(
          vaultId: jsonMap['vaultId'] as String,
          verificationToken: jsonMap['verificationToken'] as String,
          createdAt: DateTime.parse(jsonMap['createdAt'] as String),
          lastUnlockedAt: DateTime.parse(jsonMap['lastUnlockedAt'] as String),
          customDirectoryPath: jsonMap['customDirectoryPath'] as String?,
        ),
      );
    } on VaultMoveUnfinishedException {
      return const VaultFailure(VaultFailureType.vaultMoveUnfinished);
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageReadError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<void>> saveMetadata(VaultMetadata metadata) async {
    try {
      await fileDataSource.writeMetaAtomic(_metaBytes(metadata));
      return const VaultSuccess(null);
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  static List<int> _metaBytes(VaultMetadata metadata) => utf8.encode(
        jsonEncode({
          'vaultId': metadata.vaultId,
          'verificationToken': metadata.verificationToken,
          'createdAt': metadata.createdAt.toIso8601String(),
          'lastUnlockedAt': metadata.lastUnlockedAt.toIso8601String(),
          'customDirectoryPath': metadata.customDirectoryPath,
        }),
      );

  /// Moves the vault to a new key (its own password, security review
  /// 2026-10-26): every item is re-sealed from [previous] to [key] beside its
  /// old file, [beforeCommit] runs (a failure there stops the move), and one
  /// rename then puts [metadata] — the new key's wrapping — in place, after
  /// which the copies replace the old files. A stop before that rename keeps
  /// the old vault whole; a stop after it is finished at the next read of the
  /// metadata. An item with a password of its own (no screen makes one any
  /// more) cannot be re-sealed without that password, so the move is refused
  /// (`fileCorrupted`).
  Future<VaultResponse<void>> rekey({
    required VaultKey previous,
    required VaultKey key,
    required VaultMetadata metadata,
    Future<VaultFailureType?> Function()? beforeCommit,
  }) async {
    var committed = false;
    try {
      final items = await itemDataSource.getAllItems();
      if (items.any((item) => item.hasCustomPassword)) {
        return const VaultFailure(
          VaultFailureType.fileCorrupted,
          message: 'An item with its own password cannot be moved',
        );
      }
      await fileDataSource.beginRekey(_metaBytes(metadata));
      for (final item in items) {
        final bytes = await fileDataSource.readItem(item.itemId);
        if (bytes == null) continue;
        final resealRes = await cryptoRepository.reseal(
          from: previous,
          to: key,
          itemId: item.itemId,
          version: item.contentVersion,
          blob: Uint8List.fromList(bytes),
        );
        if (resealRes is VaultFailure<Uint8List>) {
          await fileDataSource.abandonRekey();
          return VaultFailure(resealRes.type, message: resealRes.message);
        }
        await fileDataSource.stageRekeyedItem(
          item.itemId,
          (resealRes as VaultSuccess<Uint8List>).data,
        );
        await _restageLabel(previous, key, item);
      }
      final stop = await beforeCommit?.call();
      if (stop != null) {
        await fileDataSource.abandonRekey();
        return VaultFailure(stop);
      }
      committed = true;
      await fileDataSource.commitRekey();
      fuzzyHub.sendSignal(const VaultDataUpdated());
      return const VaultSuccess(null);
    } on VaultMoveUnfinishedException {
      return const VaultFailure(VaultFailureType.vaultMoveUnfinished);
    } catch (e) {
      // Before the commit the old vault stays. After it, the move is finished
      // now if it can be, else at the next read of the metadata.
      try {
        if (!committed) {
          await fileDataSource.abandonRekey();
        } else if (await fileDataSource.finishInterruptedRekey()) {
          fuzzyHub.sendSignal(const VaultDataUpdated());
          return const VaultSuccess(null);
        }
      } catch (_) {}
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  /// The item's label moves to the new key with it. A label that does not
  /// open (a stop left it a version behind) is dropped: the list then shows
  /// the item's type until the item is saved again.
  Future<void> _restageLabel(
    VaultKey previous,
    VaultKey key,
    StoredVaultItem item,
  ) async {
    try {
      final bytes = await fileDataSource.readLabel(item.itemId);
      if (bytes == null) return;
      final resealRes = await cryptoRepository.reseal(
        from: previous,
        to: key,
        itemId: VaultCryptoRepository.labelIdOf(item.itemId),
        version: item.contentVersion,
        blob: Uint8List.fromList(bytes),
      );
      if (resealRes is VaultSuccess<Uint8List>) {
        await fileDataSource.stageRekeyedLabel(item.itemId, resealRes.data);
        return;
      }
      await fileDataSource.deleteLabel(item.itemId);
    } catch (e) {
      logger.w('VAULT: list label not moved: $e');
    }
  }

  /// What My safe's list shows under an item's title, never a secret: a
  /// password's username, a file's name; a note has none.
  @visibleForTesting
  static String? labelOf(VaultItem item) {
    final label = switch (item.metadata.type) {
      VaultItemType.password => item.passwordContent?.username,
      VaultItemType.file => item.fileContent?.fileName,
      VaultItemType.note => null,
    };
    final trimmed = label?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Seals [item]'s label beside it under the vault key (version [version],
  /// like the item), or removes it when the item has none. An item with a
  /// password of its own keeps no label: only that password opens anything
  /// of it. Never fails the save: without its label the row shows the type.
  Future<void> _writeLabel(
    VaultItem item,
    VaultKey key, {
    required int version,
    String? customPassword,
  }) async {
    final itemId = item.metadata.id;
    try {
      final label = labelOf(item);
      final hasOwnPassword = item.metadata.hasCustomPassword ||
          (customPassword != null && customPassword.isNotEmpty);
      final sealRes = label == null || hasOwnPassword
          ? null
          : await cryptoRepository.sealLabel(
              label,
              key,
              itemId: itemId,
              version: version,
            );
      if (sealRes is VaultSuccess<Uint8List>) {
        await fileDataSource.writeLabelAtomic(itemId, sealRes.data);
      } else {
        await fileDataSource.deleteLabel(itemId);
      }
    } catch (e) {
      logger.w('VAULT: list label not written: $e');
    }
  }

  /// The list labels of [items] (item id → label), opened with the vault
  /// key once the safe is open: only each item's small label, never the
  /// item. An item without one, with its own password, or whose label does
  /// not open, is left out (the list shows its type). Never fails.
  Future<Map<String, String>> readLabels(
    List<VaultItemMetadata> items,
    VaultKey key,
  ) async {
    final labels = <String, String>{};
    for (final item in items) {
      if (item.hasCustomPassword || item.type == VaultItemType.note) continue;
      try {
        final bytes = await fileDataSource.readLabel(item.id);
        if (bytes == null) continue;
        final label = await cryptoRepository.openLabel(
          Uint8List.fromList(bytes),
          key,
          itemId: item.id,
          version: item.contentVersion,
        );
        if (label != null && label.trim().isNotEmpty) {
          labels[item.id] = label.trim();
        }
      } catch (_) {
        // A label is only a convenience: the row shows the type instead.
      }
    }
    return labels;
  }

  Future<VaultResponse<VaultGroupData>> ensureGeneralGroup() async {
    try {
      var generalGroup =
          await groupDataSource.getGroup(VaultGroupData.generalGroupId);
      if (generalGroup == null) {
        generalGroup = StoredVaultGroup()
          ..groupId = VaultGroupData.generalGroupId
          ..name = VaultGroupData.generalGroupName
          ..emoji = '📁'
          ..colorIndex = 0
          ..sortOrder = 0
          ..hasCustomPassword = false
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
        await groupDataSource.saveGroup(generalGroup);
      }
      return VaultSuccess(VaultGroupData.fromStored(generalGroup));
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<VaultItem>> createItem(
    VaultItem item,
    VaultKey masterKey, {
    String? customPassword,
  }) async {
    try {
      await ensureGeneralGroup();

      final content = item.metadata.type == VaultItemType.password
          ? item.passwordContent
          : item.metadata.type == VaultItemType.note
              ? item.noteContent
              : item.fileContent;

      final encryptedRes = await cryptoRepository.encryptContent(
        content,
        masterKey,
        itemId: item.metadata.id,
        version: item.metadata.contentVersion,
        customPassword: customPassword,
      );

      if (encryptedRes is VaultFailure) {
        final failure = encryptedRes as VaultFailure;
        return VaultFailure(failure.type, message: failure.message);
      }
      final encryptedBytes = (encryptedRes as VaultSuccess<Uint8List>).data;

      await fileDataSource.writeItemAtomic(item.metadata.id, encryptedBytes);
      await _writeLabel(
        item,
        masterKey,
        version: item.metadata.contentVersion,
        customPassword: customPassword,
      );

      final storedItem = StoredVaultItem()
        ..itemId = item.metadata.id
        ..title = item.metadata.title
        ..groupId = item.metadata.groupId
        ..type = item.metadata.type
        ..tags = item.metadata.tags
        ..isFavorite = item.metadata.isFavorite
        ..hasCustomPassword = item.metadata.hasCustomPassword
        ..createdAt = item.metadata.createdAt
        ..updatedAt = item.metadata.updatedAt
        ..contentVersion = item.metadata.contentVersion;

      await itemDataSource.saveItem(storedItem);

      fuzzyHub.sendSignal(const VaultDataUpdated());
      return VaultSuccess(item);
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<VaultItem>> getItem(
    String itemId,
    VaultKey masterKey, {
    String? customPassword,
  }) async {
    try {
      final storedItem = await itemDataSource.getItem(itemId);
      if (storedItem == null) {
        return const VaultFailure(VaultFailureType.itemNotFound);
      }

      final encryptedBytes = await fileDataSource.readItem(itemId);
      if (encryptedBytes == null) {
        return const VaultFailure(
          VaultFailureType.fileCorrupted,
          message: 'Encrypted blob missing',
        );
      }

      var metadata = VaultItemMetadata.fromStored(storedItem);

      final decryptedRes = await cryptoRepository.decryptContent(
        Uint8List.fromList(encryptedBytes),
        masterKey,
        metadata.type,
        itemId: metadata.id,
        version: metadata.contentVersion,
        customPassword: customPassword,
      );

      if (decryptedRes is VaultFailure<VaultDecryptedContent>) {
        return VaultFailure(decryptedRes.type, message: decryptedRes.message);
      }

      final decrypted =
          (decryptedRes as VaultSuccess<VaultDecryptedContent>).data;
      final content = decrypted.content;
      if (decrypted.version != metadata.contentVersion) {
        // The file was written and the app stopped before the index caught
        // up: the index learns the version the file carries.
        storedItem.contentVersion = decrypted.version;
        await itemDataSource.saveItem(storedItem);
        metadata = metadata.copyWith(contentVersion: decrypted.version);
      }

      if (metadata.type == VaultItemType.password) {
        return VaultSuccess(
          VaultItem(
            metadata: metadata,
            passwordContent: content as VaultPasswordContent,
          ),
        );
      } else if (metadata.type == VaultItemType.note) {
        return VaultSuccess(
          VaultItem(
            metadata: metadata,
            noteContent: content as VaultNoteContent,
          ),
        );
      } else {
        return VaultSuccess(
          VaultItem(
            metadata: metadata,
            fileContent: content as VaultFileContent,
          ),
        );
      }
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageReadError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<VaultItem>> updateItem(
    VaultItem item,
    VaultKey masterKey, {
    String? customPassword,
  }) async {
    try {
      final storedItem = await itemDataSource.getItem(item.metadata.id);
      if (storedItem == null) {
        return const VaultFailure(VaultFailureType.itemNotFound);
      }

      // One past the version the index holds, whatever the caller sent: the
      // sealed file is bound to this number, and [getItem] accepts a file
      // exactly one ahead of its row.
      final updatedMetadata = item.metadata.copyWith(
        updatedAt: DateTime.now(),
        contentVersion: storedItem.contentVersion + 1,
      );

      final content = updatedMetadata.type == VaultItemType.password
          ? item.passwordContent
          : updatedMetadata.type == VaultItemType.note
              ? item.noteContent
              : item.fileContent;

      final encryptedRes = await cryptoRepository.encryptContent(
        content,
        masterKey,
        itemId: updatedMetadata.id,
        version: updatedMetadata.contentVersion,
        customPassword: customPassword,
      );

      if (encryptedRes is VaultFailure) {
        final failure = encryptedRes as VaultFailure;
        return VaultFailure(failure.type, message: failure.message);
      }
      final encryptedBytes = (encryptedRes as VaultSuccess<Uint8List>).data;

      // The file first, then the index: a stop in between leaves the file
      // one version ahead, which [getItem] accepts and records.
      await fileDataSource.writeItemAtomic(updatedMetadata.id, encryptedBytes);
      await _writeLabel(
        item.copyWith(metadata: updatedMetadata),
        masterKey,
        version: updatedMetadata.contentVersion,
        customPassword: customPassword,
      );

      storedItem
        ..title = updatedMetadata.title
        ..groupId = updatedMetadata.groupId
        ..type = updatedMetadata.type
        ..tags = updatedMetadata.tags
        ..isFavorite = updatedMetadata.isFavorite
        ..hasCustomPassword = updatedMetadata.hasCustomPassword
        ..updatedAt = updatedMetadata.updatedAt
        ..contentVersion = updatedMetadata.contentVersion;

      await itemDataSource.saveItem(storedItem);

      fuzzyHub.sendSignal(const VaultDataUpdated());

      return VaultSuccess(item.copyWith(metadata: updatedMetadata));
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<void>> deleteItem(String itemId) async {
    try {
      await fileDataSource.deleteItem(itemId);
      await itemDataSource.deleteItem(itemId);

      fuzzyHub.sendSignal(const VaultDataUpdated());
      return const VaultSuccess(null);
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<VaultItemMetadata>> moveItemToGroup(
    String itemId,
    String newGroupId,
  ) async {
    try {
      final storedItem = await itemDataSource.getItem(itemId);
      if (storedItem == null) {
        return const VaultFailure(VaultFailureType.itemNotFound);
      }

      storedItem.groupId = newGroupId;
      storedItem.updatedAt = DateTime.now();

      await itemDataSource.saveItem(storedItem);

      fuzzyHub.sendSignal(const VaultDataUpdated());

      return VaultSuccess(VaultItemMetadata.fromStored(storedItem));
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<List<VaultItemMetadata>>> getAllItems() async {
    try {
      final items = await itemDataSource.getAllItems();
      return VaultSuccess(items.map(VaultItemMetadata.fromStored).toList());
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageReadError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<List<VaultItemMetadata>>> getItemsByGroup(
    String groupId,
  ) async {
    try {
      final items = await itemDataSource.getItemsByGroup(groupId);
      return VaultSuccess(items.map(VaultItemMetadata.fromStored).toList());
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageReadError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<List<VaultItemMetadata>>> searchItems(
    String query,
  ) async {
    try {
      final items = await itemDataSource.getAllItems();
      final q = query.toLowerCase();
      final filtered = items
          .where((i) {
            return i.title.toLowerCase().contains(q) ||
                i.tags.any((t) => t.toLowerCase().contains(q));
          })
          .map(VaultItemMetadata.fromStored)
          .toList();
      return VaultSuccess(filtered);
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageReadError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<VaultGroupData>> createGroup(
    VaultGroupData group,
  ) async {
    try {
      final storedGroup = StoredVaultGroup()
        ..groupId = group.id
        ..name = group.name
        ..emoji = group.emoji
        ..colorIndex = group.colorIndex
        ..sortOrder = group.sortOrder
        ..hasCustomPassword = group.hasCustomPassword
        ..createdAt = group.createdAt
        ..updatedAt = group.updatedAt;

      await groupDataSource.saveGroup(storedGroup);
      return VaultSuccess(group);
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<List<VaultGroupData>>> getAllGroups() async {
    try {
      await ensureGeneralGroup();
      final groups = await groupDataSource.getAllGroups();
      return VaultSuccess(groups.map(VaultGroupData.fromStored).toList());
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageReadError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<VaultGroupData>> updateGroup(
    VaultGroupData group,
  ) async {
    try {
      final storedGroup = await groupDataSource.getGroup(group.id);
      if (storedGroup == null) {
        return const VaultFailure(VaultFailureType.groupNotFound);
      }

      storedGroup
        ..name = group.name
        ..emoji = group.emoji
        ..colorIndex = group.colorIndex
        ..sortOrder = group.sortOrder
        ..hasCustomPassword = group.hasCustomPassword
        ..updatedAt = DateTime.now();

      await groupDataSource.saveGroup(storedGroup);
      return VaultSuccess(VaultGroupData.fromStored(storedGroup));
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  Future<VaultResponse<void>> deleteGroup(String groupId) async {
    try {
      if (groupId == VaultGroupData.generalGroupId) {
        return const VaultFailure(VaultFailureType.generalGroupUndeletable);
      }

      final items = await itemDataSource.getItemsByGroup(groupId);
      for (final item in items) {
        item.groupId = VaultGroupData.generalGroupId;
        await itemDataSource.saveItem(item);
      }

      await groupDataSource.deleteGroup(groupId);
      return const VaultSuccess(null);
    } catch (e) {
      return VaultFailure(
        VaultFailureType.storageWriteError,
        message: e.toString(),
      );
    }
  }

  /// The master key is only re-wrapped under the new password; the items on
  /// disk are untouched.
  Future<VaultResponse<void>> changeMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    final metaRes = await getMetadata();
    if (metaRes is VaultFailure) {
      return VaultFailure(
        (metaRes as VaultFailure).type,
        message: (metaRes as VaultFailure).message,
      );
    }
    final oldMetadata = (metaRes as VaultSuccess<VaultMetadata>).data;

    final rewrapRes = await cryptoRepository.rewrap(
      oldPassword,
      newPassword,
      oldMetadata,
    );
    if (rewrapRes is VaultFailure) {
      return VaultFailure(
        (rewrapRes as VaultFailure).type,
        message: (rewrapRes as VaultFailure).message,
      );
    }
    final newMetadata = (rewrapRes as VaultSuccess<VaultMetadata>).data;

    return saveMetadata(newMetadata);
  }
}
