import '../../constants/default_constants.dart';
import 'components/components.dart';

/// Reads `https://ink.fuzzzycore.com/<kind>#<payload>` links and nothing
/// else.
///
/// The payload sits after `#`, so a browser never sends it to the link page's
/// server; the app itself makes no network call. A link is accepted only when
/// it is exactly the shape `FuzzyLinkGenerator` writes:
/// - `/invite#<blob>` and `/accept#<blob>`: the blob is the core's `Fuzz/`
///   text without its prefix (base64url, no padding);
/// - `/message#<blob>`: the message alone. The chat it belongs to is found
///   by the core's peek, which spends nothing (`PROTOCOL.md` §7.4); links no
///   longer carry the chat id in the clear (security review 2026-10-26).
///
/// Anything else (another host, a port, a user, a query, a trailing slash,
/// an escaped character outside base64url, padding, an oversized fragment)
/// is refused with `null`. Only what `Uri` itself treats as the same address
/// passes: the host's case, `:443`, an escaped letter.
/// The blob itself is checked only by the core, later.
class FuzzyLinkParser {
  static const scheme = 'https';
  static const host = 'ink.fuzzzycore.com';

  /// The longest fragment a link may carry. A message longer than this is
  /// shared as a file or as text instead of as a link.
  static const maxPayloadLength = 8192;

  static final _blob = RegExp(r'^[A-Za-z0-9_-]+$');

  static FuzzyLinkPayload? parse(Uri uri) {
    final type = FuzzyLinkType.fromPath(uri.path);
    if (type == null) return null;
    if (!uri.hasFragment) return null;

    final fragment = uri.fragment;
    if (fragment.isEmpty || fragment.length > maxPayloadLength) return null;

    // One canonical spelling only: this also refuses a port, user info, a
    // query (even an empty `?`) and any other scheme or host.
    if (uri.toString() != '$scheme://$host${type.path}#$fragment') return null;

    return switch (type) {
      FuzzyLinkType.invitation => _isBlob(fragment)
          ? InvitationLinkPayload(
              rawInvitationContent: '$fuzzIdentificator$fragment',
            )
          : null,
      FuzzyLinkType.acceptance => _isBlob(fragment)
          ? AcceptanceLinkPayload(
              rawAcceptanceContent: '$fuzzIdentificator$fragment',
            )
          : null,
      FuzzyLinkType.message => _isBlob(fragment)
          ? FuzzMessageLinkPayload(encryptedMessage: fragment)
          : null,
    };
  }

  /// A link pasted or typed as text: the whole text, trimmed, must be one
  /// link. Desktop apps receive links this way.
  static FuzzyLinkPayload? parseText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return null;
    final uri = Uri.tryParse(trimmed);
    return uri == null ? null : parse(uri);
  }

  /// The `Fuzz/` blob inside a pasted link of [type], or `null` when [text]
  /// is not exactly such a link. Lets every field that takes a pasted blob
  /// take the link as well.
  static String? blobFromPastedLink(String text, FuzzyLinkType type) {
    final payload = parseText(text);
    return switch (payload) {
      InvitationLinkPayload() when type == FuzzyLinkType.invitation =>
        payload.rawInvitationContent,
      AcceptanceLinkPayload() when type == FuzzyLinkType.acceptance =>
        payload.rawAcceptanceContent,
      FuzzMessageLinkPayload() when type == FuzzyLinkType.message =>
        '$fuzzIdentificator${payload.encryptedMessage}',
      _ => null,
    };
  }

  static bool _isBlob(String text) => _blob.hasMatch(text);
}
