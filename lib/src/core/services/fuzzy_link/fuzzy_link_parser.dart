import 'dart:convert';

import 'components/components.dart';

class FuzzyLinkParser {
  static const scheme = 'fuzzylink';

  static FuzzyLinkPayload? parse(Uri uri) {
    try {
      if (uri.scheme != scheme) return null;

      final type = FuzzyLinkType.fromUriSegment(uri.host);
      if (type == null) return null;

      final encodedPayload =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (encodedPayload == null || encodedPayload.isEmpty) return null;

      final jsonString = _decodePayload(encodedPayload);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final version = json['v'] as int?;
      if (version == null) return null;
      if (version > FuzzyLinkPayload.currentVersion) return null;

      final payloadType = json['t'] as String?;
      if (payloadType == null) return null;

      final resolvedType = FuzzyLinkType.fromPayloadCode(payloadType);
      if (resolvedType == null || resolvedType != type) return null;

      return switch (type) {
        FuzzyLinkType.invitation => _parseInvitation(json, version),
        FuzzyLinkType.acceptance => _parseAcceptance(json, version),
        FuzzyLinkType.fuzz => _parseFuzz(json, version),
      };
    } catch (_) {
      return null;
    }
  }

  static FuzzyLinkPayload? _parseInvitation(
    Map<String, dynamic> json,
    int version,
  ) {
    final blob = json['b'] as String?;
    if (blob == null || blob.isEmpty) return null;

    final exp = json['exp'] as int?;

    return InvitationLinkPayload(
      version: version,
      rawInvitationContent: blob,
      expiresAt: exp,
    );
  }

  static FuzzyLinkPayload? _parseAcceptance(
    Map<String, dynamic> json,
    int version,
  ) {
    final blob = json['b'] as String?;
    if (blob == null || blob.isEmpty) return null;

    final exp = json['exp'] as int?;

    return AcceptanceLinkPayload(
      version: version,
      rawAcceptanceContent: blob,
      expiresAt: exp,
    );
  }

  static FuzzyLinkPayload? _parseFuzz(Map<String, dynamic> json, int version) {
    final chatId = json['c'] as String?;
    final encryptedMessage = json['m'] as String?;
    if (chatId == null || encryptedMessage == null) return null;

    return FuzzMessageLinkPayload(
      version: version,
      chatId: chatId,
      encryptedMessage: encryptedMessage,
    );
  }

  static String? _decodePayload(String encoded) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(encoded));
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
