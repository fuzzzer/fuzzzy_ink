part of 'connected_chat_cubit.dart';

class ConnectedChatState {
  final StateStatus status;
  final List<MessageData> messages;
  final bool hasFetchedAllMessages;
  final DefaultFailure? failure;

  const ConnectedChatState({
    required this.status,
    required this.messages,
    this.hasFetchedAllMessages = false,
    this.failure,
  });

  ConnectedChatState copyWith({
    StateStatus? status,
    List<MessageData>? messages,
    bool? hasFetchedAllMessages,
    DefaultFailure? failure,
  }) {
    return ConnectedChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      hasFetchedAllMessages:
          hasFetchedAllMessages ?? this.hasFetchedAllMessages,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() {
    return 'ConnectedChatState(status: $status, messages: $messages, hasFetchedAllMessages: $hasFetchedAllMessages, failure: $failure)';
  }
}
