import 'dart:convert';
import 'dart:typed_data';
import 'package:fuzzzy_ink/lib.dart';

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

  /// The stored paths of the chat's file rows (sent and kept containers),
  /// without opening any seal.
  Future<List<String>> getFilePathsForChat(String chatId) async {
    final storedMessages = await localDataSource.getMessagesForChat(chatId);
    return [
      for (final stored in storedMessages)
        if (stored.messageType == MessageType.file.name)
          stored.encryptedMessage,
    ];
  }

  Future<void> deleteAllMessagesForChat(String chatId) async {
    await localDataSource.deleteAllMessagesForChat(chatId);
  }

  /// What a seal is bound to: the row's direction and its own `Fuzz/` blob
  /// text. A seal copied onto another row, or a row flipped between sent
  /// and received, no longer opens (security review 2026-10-22).
  static Uint8List _rowBinding({
    required bool isSent,
    required String encryptedMessage,
  }) {
    return Uint8List.fromList([
      if (isSent) 1 else 0,
      ...utf8.encode(encryptedMessage),
    ]);
  }

  /// A file row carries no text seal: a received file row keeps its sealed
  /// file key there instead (`PROTOCOL.md` §9.6). A text row whose seal
  /// cannot be made is still written, with the warning logged, so the blob is
  /// never lost.
  Future<String?> _sealPlaintext(MessageData message) async {
    if (!message.type.isText) return message.keptFileKey;

    final sealRes = await cryptoCoreService.sealLocal(
      chatId: message.chatId,
      row: _rowBinding(
        isSent: message.isSent,
        encryptedMessage: message.encryptedMessage,
      ),
      bytes: Uint8List.fromList(utf8.encode(message.decryptedMessage)),
    );

    if (sealRes is CryptoCoreFailure<Uint8List>) {
      logger.w('Failed to seal message plaintext: ${sealRes.type}');
      return null;
    }

    return base64Encode((sealRes as CryptoCoreSuccess<Uint8List>).data);
  }

  /// Text rows open their seal; a file row keeps its stored path in both
  /// fields and, when received, its sealed file key. A missing or corrupt
  /// seal reads as an empty message flagged `isUnreadable` and is logged,
  /// never thrown.
  Future<MessageData> _openStored(StoredMessageData stored) async {
    if (stored.messageType != MessageType.text.name) {
      return MessageData.fromStored(
        stored,
        decryptedMessage: stored.encryptedMessage,
        keptFileKey: stored.sealedPlaintext,
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
      row: _rowBinding(
        isSent: stored.isSent,
        encryptedMessage: stored.encryptedMessage,
      ),
      blob: sealed,
    );

    if (openRes is CryptoCoreFailure<Uint8List>) {
      logger.w('Failed to open message ${stored.id}: ${openRes.type}');
      return null;
    }

    return utf8.decode((openRes as CryptoCoreSuccess<Uint8List>).data);
  }
}
