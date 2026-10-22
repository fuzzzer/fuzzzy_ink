import 'package:isar_community/isar.dart';

part 'stored_vault_group.g.dart';

@collection
class StoredVaultGroup {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String groupId;

  late String name;
  late String emoji;
  late int colorIndex;
  late int sortOrder;
  late bool hasCustomPassword;
  late DateTime createdAt;
  late DateTime updatedAt;
}
