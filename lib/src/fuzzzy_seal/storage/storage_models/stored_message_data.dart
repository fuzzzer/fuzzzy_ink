import 'package:fuzzzy_seal/lib.dart';
import 'package:isar/isar.dart';

part 'stored_message_data.g.dart';

@Collection()
class StoredMessageData {
  Id id = Isar.autoIncrement;

  @Index()
  late String chatId;

  late String encryptedMessage;

  /// base64 of the 0x20 local seal of the plaintext; `null` for file rows.
  String? sealedPlaintext;
  String messageType = MessageType.text.name;

  DateTime sentAt = DateTime.now();

  bool isSent = false;
}
