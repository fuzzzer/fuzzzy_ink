import 'package:isar/isar.dart';

import '../../data/models/models.dart';

part 'stored_chat_general_data.g.dart';

@Collection()
class StoredChatGeneralData {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String chatId;

  late String chatName;

  @enumerated
  ChatSetupStatus setupStatus = ChatSetupStatus.invited;

  DateTime createdAt = DateTime.now();

  late bool didAcceptInvitation;
}
