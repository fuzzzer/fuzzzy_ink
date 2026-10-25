import 'package:fuzzzy_ink/src/src.dart';

/// What a [SealedShareContent] carries: it names the Share sheet ("Share
/// invite", "Share reply", "Share locked message").
enum SealedShareKind {
  invitation,
  acceptance,
  message;

  /// What "Copy as text" asks the copy guard for.
  CopyContent get copyContent => switch (this) {
        invitation => CopyContent.sealedInvitation,
        acceptance => CopyContent.sealedAcceptance,
        message => CopyContent.sealedMessage,
      };
}

/// One sealed text the Share action sends: an invitation, an acceptance or a
/// message. [link] is null when the text cannot travel as a link (too long),
/// and then only the file and the text are offered.
class SealedShareContent {
  const SealedShareContent({
    required this.sealedText,
    required this.link,
    required this.fileName,
    this.kind = SealedShareKind.message,
  });

  /// [invitation] is the core's `Fuzz/` text.
  factory SealedShareContent.invitation(String invitation) =>
      SealedShareContent(
        sealedText: invitation,
        link: FuzzyLinkGenerator.generateInvitationLink(invitation),
        fileName: 'fuzzzy-ink-invitation.txt',
        kind: SealedShareKind.invitation,
      );

  /// [acceptance] is the core's `Fuzz/` text.
  factory SealedShareContent.acceptance(String acceptance) =>
      SealedShareContent(
        sealedText: acceptance,
        link: FuzzyLinkGenerator.generateAcceptanceLink(acceptance),
        fileName: 'fuzzzy-ink-acceptance.txt',
        kind: SealedShareKind.acceptance,
      );

  /// [encryptedMessage] is the stored blob, without its `Fuzz/` prefix.
  factory SealedShareContent.message({
    required String chatId,
    required String encryptedMessage,
  }) =>
      SealedShareContent(
        sealedText: '$fuzzIdentificator$encryptedMessage',
        link: FuzzyLinkGenerator.generateFuzzLink(chatId, encryptedMessage),
        fileName: 'fuzzzy-ink-message.txt',
      );

  /// A QR code this long still scans from a phone screen.
  static const maxQrCodeLinkLength = 1200;

  final String sealedText;
  final String? link;
  final String fileName;
  final SealedShareKind kind;

  bool get canShowQrCode => link != null && link!.length <= maxQrCodeLinkLength;
}
