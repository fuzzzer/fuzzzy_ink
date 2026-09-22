part of 'chat_creation_cubit.dart';

class ChatCreationState {
  final StateStatus status;
  final String? chatName;
  final String? chatId;
  final CryptoCoreInvitation? generatedChatInvitation;
  final ChatCreationFailure? failure;

  const ChatCreationState({
    required this.status,
    this.chatName,
    this.chatId,
    this.generatedChatInvitation,
    this.failure,
  });

  ChatCreationState copyWith({
    StateStatus? status,
    String? chatName,
    String? chatId,
    CryptoCoreInvitation? generatedChatInvitation,
    ChatCreationFailure? failure,
  }) {
    return ChatCreationState(
      status: status ?? this.status,
      chatName: chatName ?? this.chatName,
      chatId: chatId ?? this.chatId,
      generatedChatInvitation:
          generatedChatInvitation ?? this.generatedChatInvitation,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() {
    return 'ChatCreationState(status: $status, chatName: $chatName, chatId: $chatId, generatedChatInvitation: $generatedChatInvitation, failure: $failure)';
  }
}
