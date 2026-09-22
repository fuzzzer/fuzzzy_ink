import 'dart:convert';
import 'dart:typed_data';
import 'package:fuzzzy_seal/lib.dart';

export 'events/events.dart';

class MessageDataRepository {
  final MessageDataLocalDataSource localDataSource;
  final CryptoCoreService cryptoCoreService;

  Stream<NewMessageAdded> get newMessageUpdates =>
      fuzzyHub.on<NewMessageAdded>();

  MessageDataRepository({
    required this.localDataSource,
    required this.cryptoCoreService,
  });

  /// A text message's plaintext is sealed locally (0x20) under the chat's
  /// own history key before the row is written: under the ratchet a blob
  /// decrypts once and a sender can never decrypt its own output, so the
  /// seal is the only readable copy.
  Future<int> addMessage(
    MessageData message, {
    bool notifyListeners = false,
  }) async {
    final storedMessage = StoredMessageData()
      ..chatId = message.chatId
      ..isSent = message.isSent
      ..messageType = message.type.name
      ..encryptedMessage = message.encryptedMessage
      ..sealedPlaintext = await _sealPlaintext(message);

    final id = await localDataSource.addMessage(storedMessage);

    if (notifyListeners) {
      fuzzyHub.sendSignal(
        NewMessageAdded(
          message: message.copyWith(
            id: storedMessage.id,
            sentAt: storedMessage.sentAt,
          ),
        ),
      );
    }

    return id;
  }

  Future<List<MessageData>> getMessagesForChat(String chatId) async {
    final storedMessages = await localDataSource.getMessagesForChat(chatId);
    return Future.wait(storedMessages.map(_openStored));
  }

  Future<List<MessageData>> getMessagesForChatPaginated(
    String chatId, {
    required int pageSize,
    required int pageIndex,
  }) async {
    final storedMessages = await localDataSource.getMessagesForChatPaginated(
      chatId,
      pageSize: pageSize,
      pageIndex: pageIndex,
    );

    return Future.wait(storedMessages.map(_openStored));
  }

  Future<void> deleteMessage(int messageId) async {
    await localDataSource.deleteMessage(messageId);
  }

  Future<void> deleteAllMessagesForChat(String chatId) async {
    await localDataSource.deleteAllMessagesForChat(chatId);
  }

  /// File rows (F3-3) carry no seal; a text row whose seal cannot be made is
  /// still written, with the warning logged, so the blob is never lost.
  Future<String?> _sealPlaintext(MessageData message) async {
    if (!message.type.isText) return null;

    final sealRes = await cryptoCoreService.sealLocal(
      chatId: message.chatId,
      bytes: Uint8List.fromList(utf8.encode(message.decryptedMessage)),
    );

    if (sealRes is CryptoCoreFailure<Uint8List>) {
      logger.w('Failed to seal message plaintext: ${sealRes.type}');
      return null;
    }

    return base64Encode((sealRes as CryptoCoreSuccess<Uint8List>).data);
  }

  /// Text rows open their seal; a file row keeps its path in both fields
  /// (as the connected chat did before the ratchet). A missing or corrupt
  /// seal reads as an empty message flagged `isUnreadable` and is logged,
  /// never thrown.
  Future<MessageData> _openStored(StoredMessageData stored) async {
    if (stored.messageType != MessageType.text.name) {
      return MessageData.fromStored(
        stored,
        decryptedMessage: stored.encryptedMessage,
      );
    }

    final plaintext = await _openSealedPlaintext(stored);

    return MessageData.fromStored(
      stored,
      decryptedMessage: plaintext ?? '',
      isUnreadable: plaintext == null,
    );
  }

  /// `null` when the seal is missing, malformed or will not open.
  Future<String?> _openSealedPlaintext(StoredMessageData stored) async {
    final sealedPlaintext = stored.sealedPlaintext;

    if (sealedPlaintext == null) {
      logger.w('Message ${stored.id} has no sealed plaintext');
      return null;
    }

    final Uint8List sealed;
    try {
      sealed = base64Decode(sealedPlaintext);
    } on FormatException {
      logger.w('Message ${stored.id} has a malformed sealed plaintext');
      return null;
    }

    final openRes = await cryptoCoreService.openLocal(
      chatId: stored.chatId,
      blob: sealed,
    );

    if (openRes is CryptoCoreFailure<Uint8List>) {
      logger.w('Failed to open message ${stored.id}: ${openRes.type}');
      return null;
    }

    return utf8.decode((openRes as CryptoCoreSuccess<Uint8List>).data);
  }
}
