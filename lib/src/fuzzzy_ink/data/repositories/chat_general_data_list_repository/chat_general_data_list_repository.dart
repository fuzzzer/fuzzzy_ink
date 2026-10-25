import 'package:fuzzzy_ink/lib.dart';

export 'events/events.dart';

class ChatGeneralDataListRepository {
  final ChatGeneralDataLocalDataSource localDataSource;
  final PairedAcceptanceLocalDataSource pairedAcceptanceDataSource;

  Stream<ChatGeneralDataListUpdated> get chatListUpdates =>
      fuzzyHub.on<ChatGeneralDataListUpdated>();

  ChatGeneralDataListRepository({
    required this.localDataSource,
    required this.pairedAcceptanceDataSource,
  });

  Future<List<ChatGeneralData>> getAllChats() async {
    return (await localDataSource.getAllChats())
        .map(
          ChatGeneralData.fromStored,
        )
        .toList();
  }

  Future<void> addChat(ChatGeneralData chat) async {
    final storedChatGeneralData = StoredChatGeneralData()
      ..chatId = chat.chatId
      ..chatName = chat.chatName
      ..setupStatus = chat.setupStatus
      ..didAcceptInvitation = chat.didAcceptInvitation;

    await localDataSource.addChat(
      storedChatGeneralData,
    );

    fuzzyHub.sendSignal(ChatGeneralDataListUpdated());
  }

  Future<ChatGeneralData?> getChatById(String chatId) async {
    final storedChat = await localDataSource.getChatById(chatId);
    if (storedChat != null) {
      return ChatGeneralData.fromStored(storedChat);
    }
    return null;
  }

  Future<ChatGeneralData?> getChatByName(String name) async {
    final storedChat = await localDataSource.getChatByName(name);
    if (storedChat != null) {
      return ChatGeneralData.fromStored(storedChat);
    }
    return null;
  }

  Future<void> updateChat(ChatGeneralData chat) async {
    final storedGeneralChatData =
        await localDataSource.getChatById(chat.chatId);

    if (storedGeneralChatData != null) {
      storedGeneralChatData
        ..chatName = chat.chatName
        ..setupStatus = chat.setupStatus
        ..didAcceptInvitation = chat.didAcceptInvitation;

      await localDataSource.updateChat(storedGeneralChatData);
    }

    fuzzyHub.sendSignal(ChatGeneralDataListUpdated());
  }

  Future<void> deleteChat(String chatId) async {
    await localDataSource.deleteChat(chatId);
    await pairedAcceptanceDataSource.delete(chatId);

    fuzzyHub.sendSignal(ChatGeneralDataListUpdated());
  }

  /// Remembers the acceptance that completed [chatId]'s pairing.
  Future<void> rememberPairedAcceptance(String chatId, String acceptance) =>
      pairedAcceptanceDataSource.write(chatId, _compact(acceptance));

  /// Whether [acceptance] is the one that completed [chatId]'s pairing. False
  /// when none was remembered: a different acceptance is then assumed.
  Future<bool> isPairedAcceptance(String chatId, String acceptance) async =>
      pairedAcceptanceDataSource.read(chatId) == _compact(acceptance);

  /// The core ignores whitespace inside a blob (PROTOCOL.md §6.1).
  static String _compact(String blob) => blob.replaceAll(RegExp(r'\s'), '');
}
