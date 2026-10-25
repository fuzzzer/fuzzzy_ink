import 'fuzzy_link_type.dart';

/// A parsed link. Every blob is the core's `Fuzz/` text, rebuilt from the
/// link's fragment; it is only a routing hint until the core checks it.
sealed class FuzzyLinkPayload {
  const FuzzyLinkPayload({required this.type});

  final FuzzyLinkType type;
}

class InvitationLinkPayload extends FuzzyLinkPayload {
  const InvitationLinkPayload({required this.rawInvitationContent})
      : super(type: FuzzyLinkType.invitation);

  final String rawInvitationContent;
}

class AcceptanceLinkPayload extends FuzzyLinkPayload {
  const AcceptanceLinkPayload({required this.rawAcceptanceContent})
      : super(type: FuzzyLinkType.acceptance);

  final String rawAcceptanceContent;
}

/// A message link names its chat in the clear, next to the blob: the blob
/// itself carries no chat id (PROTOCOL.md §6.5, THREAT_MODEL.md §7.4).
class FuzzMessageLinkPayload extends FuzzyLinkPayload {
  const FuzzMessageLinkPayload({
    required this.chatId,
    required this.encryptedMessage,
  }) : super(type: FuzzyLinkType.message);

  final String chatId;

  /// The blob without its `Fuzz/` prefix, as messages are stored.
  final String encryptedMessage;
}
