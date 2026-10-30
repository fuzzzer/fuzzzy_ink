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

  /// The locked part of a longer text (a whole message with a link or a
  /// `Fuzz/` text in it): the first of [findAll], or `null` when [text]
  /// holds none.
  static String? findIn(String text) => findAll(text).firstOrNull;

  /// Every locked part of a longer text, in order, each once: our links and
  /// `Fuzz/` texts, found anywhere, even glued to a word ("is:https://…",
  /// "[open it](https://…)"), with the punctuation after them left off.
  ///
  /// A locked part a mail or messenger wrapped over several lines (or that
  /// a person typed with spaces in it) comes back whole, its whitespace
  /// dropped, as the core reads it (`PROTOCOL.md` §6.1). Only the shape is
  /// checked; the core reads the rest.
  static List<String> findAll(String text) {
    final found = <String>[];
    var searchedTo = 0;
    for (final start in _starts.allMatches(text)) {
      if (start.start < searchedTo) continue;
      final part = _lockedPartAt(text, start.start);
      if (part == null) continue;
      searchedTo = part.end;
      if (!found.contains(part.text)) found.add(part.text);
    }
    return found;
  }

  /// Where a link or a `Fuzz/` text may start. The case of a link's scheme
  /// does not matter (`Uri` reads it); `Fuzz/` is checked exactly below.
  static final _starts = RegExp('https://|Fuzz/', caseSensitive: false);

  static final _word = RegExp(r'\S+');

  /// Sentence marks, quotes and brackets a messenger or a person may put
  /// after a link: a link and a `Fuzz/` text end with a base64url character.
  static final _trailing = RegExp(r'[^A-Za-z0-9_-]+$');

  /// The widths a wrapped line may have: a whole locked part is longer than
  /// the widest (a message is well over 128 characters), so an unwrapped
  /// one is never joined to the word after it.
  static const _minWrapWidth = 32;
  static const _maxWrapWidth = 128;

  /// The locked part that starts at [start] in [text], with the lines a
  /// wrap made of it joined again, or `null` when there is none there.
  static ({String text, int end})? _lockedPartAt(String text, int start) {
    final words = _word.allMatches(text, start).toList();
    final pieces = <String>[];
    final ends = <int>[];
    for (var i = 0; i < words.length; i++) {
      if (i > 0) {
        // A blank line ends what a wrap could have made.
        final gap = text.substring(words[i - 1].end, words[i].start);
        if ('\n'.allMatches(gap).length > 1) break;
      }
      final word = words[i].group(0)!;
      final piece = word.replaceFirst(_trailing, '');
      if (piece.isEmpty || (i > 0 && !_isBlob(piece))) break;
      pieces.add(piece);
      ends.add(words[i].start + piece.length);
      // Punctuation after it: nothing more can be part of it.
      if (piece.length != word.length) break;
    }
    if (pieces.isEmpty || !_isLocked(pieces.first)) return null;

    for (var last = pieces.length - 1; last > 0; last--) {
      if (!_isWrapped(pieces.sublist(0, last + 1))) continue;
      final joined = pieces.sublist(0, last + 1).join();
      if (_isLocked(joined)) return (text: joined, end: ends[last]);
    }
    return (text: pieces.first, end: ends.first);
  }

  /// Whether [pieces] look like one text wrapped at one width: every line
  /// but the first and the last exactly that wide, the first and the last no
  /// wider. The first may be narrower when words came before it on its line.
  static bool _isWrapped(List<String> pieces) {
    final width = pieces.length > 2 ? pieces[1].length : pieces.first.length;
    if (width < _minWrapWidth || width > _maxWrapWidth) return false;
    if (pieces.first.length > width || pieces.last.length > width) {
      return false;
    }
    for (var i = 1; i < pieces.length - 1; i++) {
      if (pieces[i].length != width) return false;
    }
    return true;
  }

  /// One of our links, or a `Fuzz/` text, by its shape.
  static bool _isLocked(String part) =>
      parseText(part) != null ||
      (part.startsWith(fuzzIdentificator) &&
          part.length > fuzzIdentificator.length &&
          _isBlob(part.substring(fuzzIdentificator.length)));

  static bool _isBlob(String text) => _blob.hasMatch(text);
}
