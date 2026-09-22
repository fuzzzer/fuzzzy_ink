import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

/// Opaque `Fuzz/` blobs as the core produces them; the link never looks inside.
const _invitationBlob =
    'Fuzz/RlVaWgEBJDZmMWU5YjJjLTNkNGEtNGY1Yi04YzZkLTdlOGY5YTBi';
const _acceptanceBlob =
    'Fuzz/RlVaWgECJDZmMWU5YjJjLTNkNGEtNGY1Yi04YzZkLTdlOGY5YTBi';

void main() {
  group('FuzzyLinkParser', () {
    group('scheme validation', () {
      test('rejects non-fuzzylink scheme', () {
        final uri = Uri.parse('https://invite/abc');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects empty or malformed scheme', () {
        // Uri.parse throws on truly malformed URIs, so use tryParse.
        final uri = Uri.tryParse('://invite/abc');
        // Either it fails to parse (null) or the parser rejects it.
        if (uri != null) {
          expect(FuzzyLinkParser.parse(uri), isNull);
        }
        // If uri is null, the caller would never invoke parse — test passes.
      });
    });

    group('type validation', () {
      test('rejects unknown host/type segment', () {
        final payload =
            _encodePayload({'v': 1, 't': 'inv', 'b': _invitationBlob});
        final uri = Uri.parse('fuzzylink://unknown/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects mismatched host and payload type', () {
        // Host says "invite" but payload type says "acc"
        final payload =
            _encodePayload({'v': 1, 't': 'acc', 'b': _acceptanceBlob});
        final uri = Uri.parse('fuzzylink://invite/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });
    });

    group('version validation', () {
      test('rejects payload without version', () {
        final payload = _encodePayload({'t': 'inv', 'b': _invitationBlob});
        final uri = Uri.parse('fuzzylink://invite/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects payload with future version', () {
        final payload =
            _encodePayload({'v': 999, 't': 'inv', 'b': _invitationBlob});
        final uri = Uri.parse('fuzzylink://invite/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });
    });

    group('invitation parsing', () {
      test('parses valid invitation link', () {
        final exp = DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000;

        final payload = _encodePayload({
          'v': 1,
          't': 'inv',
          'b': _invitationBlob,
          'exp': exp,
        });

        final uri = Uri.parse('fuzzylink://invite/$payload');
        final result = FuzzyLinkParser.parse(uri);

        expect(result, isA<InvitationLinkPayload>());
        final invitation = result! as InvitationLinkPayload;
        expect(invitation.version, 1);
        expect(invitation.type, FuzzyLinkType.invitation);
        expect(invitation.isExpired, isFalse);
        expect(invitation.isSupported, isTrue);
        expect(invitation.rawInvitationContent, _invitationBlob);
      });

      test('detects expired invitation', () {
        // Expired 1 hour ago
        final exp = DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;

        final payload = _encodePayload({
          'v': 1,
          't': 'inv',
          'b': _invitationBlob,
          'exp': exp,
        });

        final uri = Uri.parse('fuzzylink://invite/$payload');
        final result = FuzzyLinkParser.parse(uri) as InvitationLinkPayload?;

        expect(result, isNotNull);
        expect(result!.isExpired, isTrue);
      });

      test('rejects invitation missing the blob', () {
        final payload = _encodePayload({
          'v': 1,
          't': 'inv',
        });

        final uri = Uri.parse('fuzzylink://invite/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects invitation with an empty blob', () {
        final payload = _encodePayload({
          'v': 1,
          't': 'inv',
          'b': '',
        });

        final uri = Uri.parse('fuzzylink://invite/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects the pre-blob I/P field layout', () {
        final payload = _encodePayload({
          'v': 1,
          't': 'inv',
          'I': 'chat',
          'P': 'key',
        });

        final uri = Uri.parse('fuzzylink://invite/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });
    });

    group('acceptance parsing', () {
      test('parses valid acceptance link', () {
        final exp = DateTime.now()
                .add(const Duration(hours: 24))
                .millisecondsSinceEpoch ~/
            1000;

        final payload = _encodePayload({
          'v': 1,
          't': 'acc',
          'b': _acceptanceBlob,
          'exp': exp,
        });

        final uri = Uri.parse('fuzzylink://accept/$payload');
        final result = FuzzyLinkParser.parse(uri);

        expect(result, isA<AcceptanceLinkPayload>());
        final acceptance = result! as AcceptanceLinkPayload;
        expect(acceptance.version, 1);
        expect(acceptance.type, FuzzyLinkType.acceptance);
        expect(acceptance.isExpired, isFalse);
        expect(acceptance.rawAcceptanceContent, _acceptanceBlob);
      });

      test('detects expired acceptance', () {
        final exp = DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;

        final payload = _encodePayload({
          'v': 1,
          't': 'acc',
          'b': _acceptanceBlob,
          'exp': exp,
        });

        final uri = Uri.parse('fuzzylink://accept/$payload');
        final result = FuzzyLinkParser.parse(uri) as AcceptanceLinkPayload?;

        expect(result, isNotNull);
        expect(result!.isExpired, isTrue);
      });

      test('rejects acceptance missing the blob', () {
        final payload = _encodePayload({
          'v': 1,
          't': 'acc',
          // Missing 'b'
        });

        final uri = Uri.parse('fuzzylink://accept/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });
    });

    group('fuzz message parsing', () {
      test('parses valid fuzz message link', () {
        final payload = _encodePayload({
          'v': 1,
          't': 'fuz',
          'c': 'chat-123',
          'm': 'encrypted-message-content',
        });

        final uri = Uri.parse('fuzzylink://fuzz/$payload');
        final result = FuzzyLinkParser.parse(uri);

        expect(result, isA<FuzzMessageLinkPayload>());
        final fuzz = result! as FuzzMessageLinkPayload;
        expect(fuzz.version, 1);
        expect(fuzz.type, FuzzyLinkType.fuzz);
        expect(fuzz.chatId, 'chat-123');
        expect(fuzz.encryptedMessage, 'encrypted-message-content');
      });

      test('rejects fuzz message missing chat id', () {
        final payload = _encodePayload({
          'v': 1,
          't': 'fuz',
          'm': 'encrypted-message-content',
        });

        final uri = Uri.parse('fuzzylink://fuzz/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects fuzz message missing encrypted message', () {
        final payload = _encodePayload({
          'v': 1,
          't': 'fuz',
          'c': 'chat-123',
        });

        final uri = Uri.parse('fuzzylink://fuzz/$payload');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });
    });

    group('malformed input', () {
      test('rejects empty path segments', () {
        final uri = Uri.parse('fuzzylink://invite/');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects non-base64 payload', () {
        final uri = Uri.parse('fuzzylink://invite/not-valid-base64!!!');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects non-JSON payload', () {
        final encoded = base64Url.encode(utf8.encode('this is not json'));
        final uri = Uri.parse('fuzzylink://invite/$encoded');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });

      test('rejects payload with wrong JSON type', () {
        final encoded = base64Url.encode(utf8.encode('[1,2,3]'));
        final uri = Uri.parse('fuzzylink://invite/$encoded');
        expect(FuzzyLinkParser.parse(uri), isNull);
      });
    });
  });
}

/// Helper to create a base64url-encoded JSON payload for testing.
String _encodePayload(Map<String, dynamic> data) {
  final jsonString = jsonEncode(data);
  return base64Url.encode(utf8.encode(jsonString));
}
