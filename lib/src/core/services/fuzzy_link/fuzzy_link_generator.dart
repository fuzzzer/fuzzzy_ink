import 'dart:convert';

import 'components/components.dart';

class FuzzyLinkGenerator {
  static const _scheme = 'fuzzylink';
  static const _expirationDuration = Duration(hours: 24);

  /// [invitationContent] is the opaque `Fuzz/` blob, carried as one field.
  static String generateInvitationLink(String invitationContent) {
    final payload = jsonEncode({
      'v': FuzzyLinkPayload.currentVersion,
      't': FuzzyLinkType.invitation.payloadCode,
      'b': invitationContent,
      'exp': _generateExpirationTimestamp(),
    });
    final encoded = _encodePayload(payload);
    return '$_scheme://invite/$encoded';
  }

  static String generateAcceptanceLink(String acceptanceContent) {
    final payload = jsonEncode({
      'v': FuzzyLinkPayload.currentVersion,
      't': FuzzyLinkType.acceptance.payloadCode,
      'b': acceptanceContent,
      'exp': _generateExpirationTimestamp(),
    });
    final encoded = _encodePayload(payload);
    return '$_scheme://accept/$encoded';
  }

  static String generateFuzzLink(String chatId, String encryptedMessage) {
    final payload = jsonEncode({
      'v': FuzzyLinkPayload.currentVersion,
      't': FuzzyLinkType.fuzz.payloadCode,
      'c': chatId,
      'm': encryptedMessage,
    });
    final encoded = _encodePayload(payload);
    return '$_scheme://fuzz/$encoded';
  }

  static String generateShareableContent({
    required String link,
    required String rawFuzz,
    required FuzzyLinkType type,
  }) {
    final typeLabel = switch (type) {
      FuzzyLinkType.invitation => 'Invitation',
      FuzzyLinkType.acceptance => 'Acceptance',
      FuzzyLinkType.fuzz => 'Encrypted Message',
    };

    return '🔐 Fuzzzy Ink $typeLabel\n'
        '\n'
        'Tap the link to open in Fuzzzy Ink:\n'
        '$link\n'
        '\n'
        '────────────────────\n'
        "Can't tap? Copy the text below and paste into Fuzzzy Ink:\n"
        '$rawFuzz';
  }

  static int _generateExpirationTimestamp() {
    return DateTime.now().add(_expirationDuration).millisecondsSinceEpoch ~/
        1000;
  }

  static String _encodePayload(String json) {
    final bytes = utf8.encode(json);
    return base64Url.encode(bytes);
  }
}
