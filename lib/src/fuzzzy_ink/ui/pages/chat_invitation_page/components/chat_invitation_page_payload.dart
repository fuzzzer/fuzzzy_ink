class ChatInvitationPagePayload {
  final String chatName;
  final String chatId;
  final String? prefillAcceptanceContent;

  ChatInvitationPagePayload({
    required this.chatName,
    required this.chatId,
    this.prefillAcceptanceContent,
  });
}
