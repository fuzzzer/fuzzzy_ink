import 'package:isar_community/isar.dart';
import '../storage_models/stored_vault_group.dart';

class VaultGroupLocalDataSource {
  const VaultGroupLocalDataSource({required this.isar});
  final Isar isar;

  Future<void> saveGroup(StoredVaultGroup group) async {
    await isar.writeTxn(() async {
      await isar.storedVaultGroups.put(group);
    });
  }

  Future<StoredVaultGroup?> getGroup(String groupId) async {
    return isar.storedVaultGroups.filter().groupIdEqualTo(groupId).findFirst();
  }

  Future<List<StoredVaultGroup>> getAllGroups() async {
    return isar.storedVaultGroups.where().findAll();
  }

  Future<void> deleteGroup(String groupId) async {
    await isar.writeTxn(() async {
      await isar.storedVaultGroups.filter().groupIdEqualTo(groupId).deleteAll();
    });
  }
}
