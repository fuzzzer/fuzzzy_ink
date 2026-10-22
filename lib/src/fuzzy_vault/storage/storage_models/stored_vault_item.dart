import 'package:isar_community/isar.dart';
import '../../data/models/vault_item_type.dart';

part 'stored_vault_item.g.dart';

@collection
class StoredVaultItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String itemId;

  @Index()
  late String title;

  @Index()
  late String groupId;

  @Enumerated(EnumType.ordinal)
  late VaultItemType type;

  late List<String> tags;

  late bool isFavorite;

  late bool hasCustomPassword;

  late DateTime createdAt;
  late DateTime updatedAt;
  late int contentVersion;
}
