import '../../storage/storage.dart';
import 'enums/enums.dart';

class ChatGeneralData {
  final String chatId;
  final String chatName;
  final ChatSetupStatus setupStatus;
  final bool didAcceptInvitation;

  ChatGeneralData({
    required this.chatId,
    required this.chatName,
    required this.setupStatus,
    required this.didAcceptInvitation,
  });

  factory ChatGeneralData.fromStored(StoredChatGeneralData stored) {
    return ChatGeneralData(
      chatId: stored.chatId,
      chatName: stored.chatName,
      setupStatus: stored.setupStatus,
      didAcceptInvitation: stored.didAcceptInvitation,
    );
  }

  ChatGeneralData copyWith({
    String? chatId,
    String? chatName,
    ChatSetupStatus? setupStatus,
    bool? didAcceptInvitation,
  }) {
    return ChatGeneralData(
      chatId: chatId ?? this.chatId,
      chatName: chatName ?? this.chatName,
      setupStatus: setupStatus ?? this.setupStatus,
      didAcceptInvitation: didAcceptInvitation ?? this.didAcceptInvitation,
    );
  }

  @override
  String toString() =>
      'ChatGeneralData(chatId: $chatId, chatName: $chatName, setupStatus: $setupStatus, didAcceptInvitation: $didAcceptInvitation)';
}
