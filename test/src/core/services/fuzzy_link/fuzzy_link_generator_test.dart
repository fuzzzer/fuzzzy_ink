import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';

/// Opaque `Fuzz/` blobs as the core produces them; the link never looks inside.
const _invitationBlob =
    'Fuzz/RlVaWgEBJDZmMWU5YjJjLTNkNGEtNGY1Yi04YzZkLTdlOGY5YTBi';
const _acceptanceBlob =
    'Fuzz/RlVaWgECJDZmMWU5YjJjLTNkNGEtNGY1Yi04YzZkLTdlOGY5YTBi';

Map<String, dynamic> _decodePayload(String link) {
  final encodedPayload = Uri.parse(link).pathSegments.first;
  final jsonString =
      utf8.decode(base64Url.decode(base64Url.normalize(encodedPayload)));
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

void main() {
  group('FuzzyLinkGenerator', () {
    group('generateInvitationLink', () {
      test('generates valid invitation URI', () {
        final link = FuzzyLinkGenerator.generateInvitationLink(_invitationBlob);

        expect(link, startsWith('fuzzylink://invite/'));
        final uri = Uri.parse(link);
        expect(uri.scheme, 'fuzzylink');
        expect(uri.host, 'invite');
        expect(uri.pathSegments, hasLength(1));
        expect(uri.pathSegments.first, isNotEmpty);
      });

      test('generated invitation link round-trips through parser', () {
        final link = FuzzyLinkGenerator.generateInvitationLink(_invitationBlob);
        final parsed = FuzzyLinkParser.parse(Uri.parse(link));

        expect(parsed, isA<InvitationLinkPayload>());
        final invitation = parsed! as InvitationLinkPayload;
        expect(invitation.version, FuzzyLinkPayload.currentVersion);
        expect(invitation.type, FuzzyLinkType.invitation);
        expect(invitation.isExpired, isFalse);

        // The blob comes back byte for byte.
        expect(invitation.rawInvitationContent, _invitationBlob);
      });

      test('invitation link carries the blob as the single `b` field', () {
        final link = FuzzyLinkGenerator.generateInvitationLink(_invitationBlob);
        final json = _decodePayload(link);

        expect(json['b'], _invitationBlob);
        expect(json['t'], 'inv');
        expect(json.keys, unorderedEquals(['v', 't', 'b', 'exp']));
      });

      test('invitation link includes expiration', () {
        final link = FuzzyLinkGenerator.generateInvitationLink(_invitationBlob);
        final parsed =
            FuzzyLinkParser.parse(Uri.parse(link))! as InvitationLinkPayload;

        expect(parsed.expiresAt, isNotNull);
        expect(parsed.isExpired, isFalse);
      });
    });

    group('generateAcceptanceLink', () {
      test('generates valid acceptance URI', () {
        final link = FuzzyLinkGenerator.generateAcceptanceLink(_acceptanceBlob);

        expect(link, startsWith('fuzzylink://accept/'));
        final uri = Uri.parse(link);
        expect(uri.scheme, 'fuzzylink');
        expect(uri.host, 'accept');
      });

      test('generated acceptance link round-trips through parser', () {
        final link = FuzzyLinkGenerator.generateAcceptanceLink(_acceptanceBlob);
        final parsed = FuzzyLinkParser.parse(Uri.parse(link));

        expect(parsed, isA<AcceptanceLinkPayload>());
        final acceptance = parsed! as AcceptanceLinkPayload;
        expect(acceptance.version, FuzzyLinkPayload.currentVersion);
        expect(acceptance.type, FuzzyLinkType.acceptance);
        expect(acceptance.isExpired, isFalse);

        expect(acceptance.rawAcceptanceContent, _acceptanceBlob);
      });

      test('acceptance link carries the blob as the single `b` field', () {
        final link = FuzzyLinkGenerator.generateAcceptanceLink(_acceptanceBlob);
        final json = _decodePayload(link);

        expect(json['b'], _acceptanceBlob);
        expect(json['t'], 'acc');
        expect(json.keys, unorderedEquals(['v', 't', 'b', 'exp']));
      });
    });

    group('generateFuzzLink', () {
      test('generates valid fuzz message URI', () {
        final link =
            FuzzyLinkGenerator.generateFuzzLink('chat-id-123', 'encrypted-msg');

        expect(link, startsWith('fuzzylink://fuzz/'));
        final uri = Uri.parse(link);
        expect(uri.scheme, 'fuzzylink');
        expect(uri.host, 'fuzz');
      });

      test('generated fuzz link round-trips through parser', () {
        const chatId = 'fuzz-round-trip-chat';
        const encryptedMessage = 'U2FsdGVkX1+encrypted+content';

        final link =
            FuzzyLinkGenerator.generateFuzzLink(chatId, encryptedMessage);
        final parsed = FuzzyLinkParser.parse(Uri.parse(link));

        expect(parsed, isA<FuzzMessageLinkPayload>());
        final fuzz = parsed! as FuzzMessageLinkPayload;
        expect(fuzz.version, FuzzyLinkPayload.currentVersion);
        expect(fuzz.chatId, chatId);
        expect(fuzz.encryptedMessage, encryptedMessage);
      });

      test('fuzz link has no expiration', () {
        final link = FuzzyLinkGenerator.generateFuzzLink('chat-1', 'msg');

        // Decode and check there's no 'exp' field
        final json = _decodePayload(link);

        expect(json.containsKey('exp'), isFalse);
      });
    });

    group('generateShareableContent', () {
      test('generates hybrid share text with link and raw fuzz', () {
        const link = 'fuzzylink://invite/abc123';
        const rawFuzz = _invitationBlob;

        final content = FuzzyLinkGenerator.generateShareableContent(
          link: link,
          rawFuzz: rawFuzz,
          type: FuzzyLinkType.invitation,
        );

        expect(content, contains('Fuzzzy Seal Invitation'));
        expect(content, contains(link));
        expect(content, contains(rawFuzz));
        expect(content, contains('────────────────────'));
      });

      test('labels fuzz message type correctly', () {
        final content = FuzzyLinkGenerator.generateShareableContent(
          link: 'fuzzylink://fuzz/xyz',
          rawFuzz: 'encrypted',
          type: FuzzyLinkType.fuzz,
        );

        expect(content, contains('Encrypted Message'));
      });

      test('labels acceptance type correctly', () {
        final content = FuzzyLinkGenerator.generateShareableContent(
          link: 'fuzzylink://accept/xyz',
          rawFuzz: 'acceptance-data',
          type: FuzzyLinkType.acceptance,
        );

        expect(content, contains('Acceptance'));
      });
    });
  });
}
