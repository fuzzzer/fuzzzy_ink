import 'package:isar/isar.dart';
import '../storage_models/storage_models.dart';

class ChatPreferencesLocalDataSource {
  final Isar isar;

  ChatPreferencesLocalDataSource(this.isar);

  Future<StoredChatPreferences?> getChatPreferences() async {
    return await isar.storedChatPreferences.where().findFirst();
  }

  Future<void> saveChatPreferences(StoredChatPreferences preferences) async {
    await isar.writeTxn(() async {
      await isar.storedChatPreferences.put(preferences);
    });
  }

  Future<void> updateChatPreferences(StoredChatPreferences preferences) async {
    await isar.writeTxn(() async {
      await isar.storedChatPreferences.put(preferences);
    });
  }
}
