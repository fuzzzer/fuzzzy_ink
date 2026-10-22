import 'package:isar_community/isar.dart';
import '../storage_models/stored_vault_item.dart';

class VaultItemLocalDataSource {
  const VaultItemLocalDataSource({required this.isar});
  final Isar isar;

  Future<void> saveItem(StoredVaultItem item) async {
    await isar.writeTxn(() async {
      await isar.storedVaultItems.put(item);
    });
  }

  Future<StoredVaultItem?> getItem(String itemId) async {
    return isar.storedVaultItems.filter().itemIdEqualTo(itemId).findFirst();
  }

  Future<List<StoredVaultItem>> getAllItems() async {
    return isar.storedVaultItems.where().findAll();
  }

  Future<List<StoredVaultItem>> getItemsByGroup(String groupId) async {
    return isar.storedVaultItems.filter().groupIdEqualTo(groupId).findAll();
  }

  Future<void> deleteItem(String itemId) async {
    await isar.writeTxn(() async {
      await isar.storedVaultItems.filter().itemIdEqualTo(itemId).deleteAll();
    });
  }
}
