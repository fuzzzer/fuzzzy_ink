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

/// A message link carries the blob only; Open finds its chat with the
/// core's peek and opens it only when the person taps Open (security review
/// 2026-10-26).
class FuzzMessageLinkPayload extends FuzzyLinkPayload {
  const FuzzMessageLinkPayload({required this.encryptedMessage})
      : super(type: FuzzyLinkType.message);

  /// The blob without its `Fuzz/` prefix, as messages are stored.
  final String encryptedMessage;
}
