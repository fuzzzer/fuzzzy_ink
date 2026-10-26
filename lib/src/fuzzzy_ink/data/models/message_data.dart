import 'package:fuzzzy_ink/lib.dart';

class MessageData {
  final int id;
  final String chatId;
  final MessageType type;
  final String encryptedMessage;
  final String decryptedMessage;
  final DateTime sentAt;
  final bool isSent;

  /// `true` when a text row's local seal could not be opened, so an empty
  /// [decryptedMessage] means "unreadable", not "empty" (F2-10 export marker).
  final bool isUnreadable;

  /// A received file row: the kept container's file key, sealed under the
  /// chat's history key, base64 (`PROTOCOL.md` §9.6). `null` on every other
  /// row; [encryptedMessage] is then the kept container's stored path.
  final String? keptFileKey;

  MessageData({
    required this.id,
    required this.chatId,
    required this.type,
    required this.encryptedMessage,
    required this.decryptedMessage,
    required this.sentAt,
    required this.isSent,
    this.isUnreadable = false,
    this.keptFileKey,
  });

  /// [decryptedMessage] is the opened local seal — the repository fills it,
  /// and flags [isUnreadable] when the seal would not open.
  factory MessageData.fromStored(
    StoredMessageData stored, {
    String decryptedMessage = '',
    bool isUnreadable = false,
    String? keptFileKey,
  }) {
    return MessageData(
      id: stored.id,
      chatId: stored.chatId,
      type: MessageType.values.firstWhereOrNull(
            (messageType) => messageType.name == stored.messageType,
          ) ??
          MessageType.text,
      encryptedMessage: stored.encryptedMessage,
      decryptedMessage: decryptedMessage,
      sentAt: stored.sentAt,
      isSent: stored.isSent,
      isUnreadable: isUnreadable,
      keptFileKey: keptFileKey,
    );
  }

  MessageData copyWith({
    int? id,
    String? chatId,
    MessageType? type,
    String? encryptedMessage,
    String? decryptedMessage,
    DateTime? sentAt,
    bool? isSent,
    bool? isUnreadable,
    String? keptFileKey,
  }) {
    return MessageData(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      encryptedMessage: encryptedMessage ?? this.encryptedMessage,
      decryptedMessage: decryptedMessage ?? this.decryptedMessage,
      sentAt: sentAt ?? this.sentAt,
      isSent: isSent ?? this.isSent,
      isUnreadable: isUnreadable ?? this.isUnreadable,
      keptFileKey: keptFileKey ?? this.keptFileKey,
    );
  }

  @override
  // Never the opened text: rows end up in development and profile logs
  // (security review 2026-10-26).
  String toString() {
    return 'MessageData(id: $id, chatId: $chatId, type: $type, sentAt: $sentAt, isSent: $isSent, isUnreadable: $isUnreadable, hasKeptFileKey: ${keptFileKey != null})';
  }
}
