import '../../constants/default_constants.dart';
import 'components/components.dart';
import 'fuzzy_link_parser.dart';

/// Writes the links [FuzzyLinkParser] reads. Each answer is `null` when the
/// content cannot travel as a link: not a `Fuzz/` blob, or longer than
/// [FuzzyLinkParser.maxPayloadLength]. A sealed file never becomes a link; it
/// is shared as the file itself.
class FuzzyLinkGenerator {
  /// [invitationContent] is the core's `Fuzz/` text.
  static String? generateInvitationLink(String invitationContent) =>
      _link(FuzzyLinkType.invitation, _blobBody(invitationContent));

  /// [acceptanceContent] is the core's `Fuzz/` text.
  static String? generateAcceptanceLink(String acceptanceContent) =>
      _link(FuzzyLinkType.acceptance, _blobBody(acceptanceContent));

  /// [encryptedMessage] is a message blob, with or without its `Fuzz/`
  /// prefix. Nothing else rides along: the receiving app finds the chat with
  /// the core's peek.
  static String? generateFuzzLink(String encryptedMessage) =>
      _link(FuzzyLinkType.message, _blobBody(encryptedMessage));

  static String _blobBody(String text) {
    final compact = text.replaceAll(RegExp(r'\s'), '');
    return compact.startsWith(fuzzIdentificator)
        ? compact.substring(fuzzIdentificator.length)
        : compact;
  }

  static String? _link(FuzzyLinkType type, String fragment) {
    final link = '${FuzzyLinkParser.scheme}://${FuzzyLinkParser.host}'
        '${type.path}#$fragment';
    return FuzzyLinkParser.parseText(link) == null ? null : link;
  }
}
