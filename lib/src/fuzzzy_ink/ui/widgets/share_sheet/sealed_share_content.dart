import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

/// What a [SealedShareContent] carries: it names the Share sheet ("Share
/// invite", "Share reply", "Share locked message", "Share locked file").
enum SealedShareKind {
  invitation,
  acceptance,
  message,

  /// Text locked with a password: "They need the password."
  passwordText,

  /// A locked `.fuzz` file the app keeps: it travels only as that file.
  file;

  /// What "Copy as text" asks the copy guard for (a file is never copied).
  CopyContent get copyContent => switch (this) {
        invitation => CopyContent.sealedInvitation,
        acceptance => CopyContent.sealedAcceptance,
        message => CopyContent.sealedMessage,
        passwordText => CopyContent.sealedText,
        file => CopyContent.plaintext,
      };
}

/// One sealed thing the Share action sends: an invitation, an acceptance, a
/// message, a password-locked text or a locked file. [link] is null when it
/// cannot travel as a link (too long, a password text, a file), and then
/// only the file and the text are offered.
///
/// "Send as a file" sends locked text as a small `.fuzz` file holding the
/// `Fuzz/` text: Open → Choose a file reads it like a paste (the core's
/// peek tells a text file from a container by its first bytes).
class SealedShareContent {
  const SealedShareContent({
    required this.sealedText,
    required this.link,
    required this.fileName,
    this.kind = SealedShareKind.message,
    this.filePath,
  });

  /// [invitation] is the core's `Fuzz/` text.
  factory SealedShareContent.invitation(String invitation) =>
      SealedShareContent(
        sealedText: invitation,
        link: FuzzyLinkGenerator.generateInvitationLink(invitation),
        fileName: 'fuzzzy-ink-invitation.$fuzzedFileIdentificator',
        kind: SealedShareKind.invitation,
      );

  /// [acceptance] is the core's `Fuzz/` text.
  factory SealedShareContent.acceptance(String acceptance) =>
      SealedShareContent(
        sealedText: acceptance,
        link: FuzzyLinkGenerator.generateAcceptanceLink(acceptance),
        fileName: 'fuzzzy-ink-reply.$fuzzedFileIdentificator',
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
        fileName: 'fuzzzy-ink-message.$fuzzedFileIdentificator',
      );

  /// [sealedText] is a password-sealed `Fuzz/` text (Basics): no link, it
  /// travels as text or a `.fuzz` file.
  factory SealedShareContent.passwordText(String sealedText) =>
      SealedShareContent(
        sealedText: sealedText,
        link: null,
        fileName: 'fuzzzy-ink-locked.$fuzzedFileIdentificator',
        kind: SealedShareKind.passwordText,
      );

  /// The locked `.fuzz` file at [filePath], sent as that file only. Too big
  /// for a link or a QR code, and never copied.
  factory SealedShareContent.lockedFile(String filePath) => SealedShareContent(
        sealedText: '',
        link: null,
        fileName: path.basename(filePath),
        kind: SealedShareKind.file,
        filePath: filePath,
      );

  /// A QR code this long still scans from a phone screen.
  static const maxQrCodeLinkLength = 1200;

  final String sealedText;
  final String? link;
  final String fileName;
  final SealedShareKind kind;

  /// Set for a locked file: the file itself is what is sent.
  final String? filePath;

  bool get isFile => filePath != null;

  bool get canShowQrCode => link != null && link!.length <= maxQrCodeLinkLength;
}
