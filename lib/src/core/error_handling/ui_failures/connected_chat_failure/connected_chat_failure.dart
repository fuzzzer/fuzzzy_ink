import 'connected_chat_failure_type.dart';

export 'components.dart';
export 'connected_chat_failure_type.dart';

class ConnectedChatFailure {
  ///Not to be used to show user
  final String? internalMessage;

  ///To be used to generate message for user, for ui to generate localized message
  final ConnectedChatFailureType type;

  ConnectedChatFailure({
    this.internalMessage,
    required this.type,
  });
}
