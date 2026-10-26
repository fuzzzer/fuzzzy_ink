class ChatInvitationPagePayload {
  final String chatName;
  final String chatId;

  /// A reply to complete the pairing with (a tapped reply link, or "I got
  /// the reply"): the page connects at once.
  final String? prefillAcceptanceContent;

  /// The invite was made just now (step 2 of 2 of "Send an invite"): its
  /// first step fills once.
  final bool justMade;

  ChatInvitationPagePayload({
    required this.chatName,
    required this.chatId,
    this.prefillAcceptanceContent,
    this.justMade = false,
  });
}
