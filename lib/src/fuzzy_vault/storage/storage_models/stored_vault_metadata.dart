import 'package:isar/isar.dart';

part 'stored_vault_metadata.g.dart';

@collection
class StoredVaultMetadata {
  Id id = Isar.autoIncrement;

  late String vaultId;
  late String verificationTokenBase64;
  late DateTime createdAt;
  late DateTime lastUnlockedAt;
  late int autoLockMinutes;
  late String? customDirectoryPath;
}
