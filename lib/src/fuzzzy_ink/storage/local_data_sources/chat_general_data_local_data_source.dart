import 'package:isar/isar.dart';
import '../storage_models/storage_models.dart';

class ChatGeneralDataLocalDataSource {
  final Isar isar;

  ChatGeneralDataLocalDataSource({required this.isar});

  Future<List<StoredChatGeneralData>> getAllChats() async {
    return await isar.storedChatGeneralDatas.where().findAll();
  }

  Future<void> addChat(StoredChatGeneralData storedChatGeneralData) async {
    await isar.writeTxn(() async {
      await isar.storedChatGeneralDatas.put(storedChatGeneralData);
    });
  }

  Future<StoredChatGeneralData?> getChatById(String chatId) async {
    return await isar.storedChatGeneralDatas
        .filter()
        .chatIdEqualTo(chatId)
        .findFirst();
  }

  Future<StoredChatGeneralData?> getChatByName(String name) async {
    return await isar.storedChatGeneralDatas
        .filter()
        .chatNameEqualTo(name)
        .findFirst();
  }

  Future<void> updateChat(StoredChatGeneralData storedChatGeneralData) async {
    await isar.writeTxn(() async {
      await isar.storedChatGeneralDatas.put(storedChatGeneralData);
    });
  }

  Future<void> deleteChat(String chatId) async {
    final storedChatGeneralData = await getChatById(chatId);
    if (storedChatGeneralData != null) {
      await isar.writeTxn(() async {
        await isar.storedChatGeneralDatas.delete(storedChatGeneralData.id);
      });
    }
  }
}
