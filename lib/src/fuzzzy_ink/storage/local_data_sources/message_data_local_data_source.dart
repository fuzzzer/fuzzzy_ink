import 'package:isar/isar.dart';
import '../storage_models/storage_models.dart';

class MessageDataLocalDataSource {
  final Isar isar;

  MessageDataLocalDataSource({required this.isar});

  Future<int> addMessage(StoredMessageData messageData) async {
    return await isar.writeTxn<int>(() async {
      return await isar.storedMessageDatas.put(messageData);
    });
  }

  Future<List<StoredMessageData>> getMessagesForChat(String chatId) async {
    return await isar.storedMessageDatas
        .filter()
        .chatIdEqualTo(chatId)
        .sortBySentAt()
        .findAll();
  }

  Future<List<StoredMessageData>> getMessagesForChatPaginated(
    String chatId, {
    required int pageSize,
    required int pageIndex,
  }) async {
    final offset = pageIndex * pageSize;

    return await isar.storedMessageDatas
        .filter()
        .chatIdEqualTo(chatId)
        .sortBySentAtDesc()
        .offset(offset)
        .limit(pageSize)
        .findAll();
  }

  Future<int> updateMessage(StoredMessageData messageData) async {
    return await isar.writeTxn<int>(() async {
      return await isar.storedMessageDatas.put(messageData);
    });
  }

  Future<void> deleteMessage(int messageId) async {
    await isar.writeTxn(() async {
      await isar.storedMessageDatas.delete(messageId);
    });
  }

  Future<void> deleteAllMessagesForChat(String chatId) async {
    final messages = await getMessagesForChat(chatId);
    await isar.writeTxn(() async {
      for (final message in messages) {
        await isar.storedMessageDatas.delete(message.id);
      }
    });
  }
}
