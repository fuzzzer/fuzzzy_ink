import 'package:fuzzzy_seal/lib.dart';

class ConnectedChatPagePayload {
  final ChatGeneralData chatGeneralData;
  final String? prefillEncryptedMessage;

  /// Opens the safety-number page on top of the chat once it is shown
  /// (the inviter's entry point after a completed handshake).
  final bool openSafetyNumber;

  ConnectedChatPagePayload({
    required this.chatGeneralData,
    this.prefillEncryptedMessage,
    this.openSafetyNumber = false,
  });
}
