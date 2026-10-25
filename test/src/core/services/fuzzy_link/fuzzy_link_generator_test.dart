import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

/// Opaque blobs as the core produces them; the link never looks inside.
final _invitationBody = 'RlVaWgEB${'A' * 263}';
final _acceptanceBody = 'RlVaWgEC${'B' * 600}';
const _messageBody = 'RlVaWgEDAQ-_xyz09';
const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

void main() {
  group('FuzzyLinkGenerator', () {
    test('an invitation link carries the blob after #, never in the path', () {
      final link =
          FuzzyLinkGenerator.generateInvitationLink('Fuzz/$_invitationBody');

      expect(link, 'https://ink.fuzzzycore.com/invite#$_invitationBody');
      final uri = Uri.parse(link!);
      expect(uri.path, '/invite');
      expect(uri.hasQuery, isFalse);
    });

    test('an acceptance link round-trips through the parser', () {
      final link =
          FuzzyLinkGenerator.generateAcceptanceLink('Fuzz/$_acceptanceBody');
      final payload = FuzzyLinkParser.parse(Uri.parse(link!));

      expect(link, 'https://ink.fuzzzycore.com/accept#$_acceptanceBody');
      expect(
        (payload! as AcceptanceLinkPayload).rawAcceptanceContent,
        'Fuzz/$_acceptanceBody',
      );
    });

    test('a message link names the chat and round-trips', () {
      final link = FuzzyLinkGenerator.generateFuzzLink(_chatId, _messageBody);
      final payload = FuzzyLinkParser.parse(Uri.parse(link!));

      expect(link, 'https://ink.fuzzzycore.com/message#$_chatId.$_messageBody');
      final typed = payload! as FuzzMessageLinkPayload;
      expect(typed.chatId, _chatId);
      expect(typed.encryptedMessage, _messageBody);
    });

    test('a message blob with or without its Fuzz/ prefix gives one link', () {
      expect(
        FuzzyLinkGenerator.generateFuzzLink(_chatId, 'Fuzz/$_messageBody'),
        FuzzyLinkGenerator.generateFuzzLink(_chatId, _messageBody),
      );
    });

    test('a blob wrapped by an e-mail client is joined back up', () {
      final wrapped = 'Fuzz/${_invitationBody.substring(0, 60)}\r\n  '
          '${_invitationBody.substring(60)}\n';
      expect(
        FuzzyLinkGenerator.generateInvitationLink(wrapped),
        'https://ink.fuzzzycore.com/invite#$_invitationBody',
      );
    });

    group('gives no link for', () {
      test('a message longer than the link limit', () {
        final body = 'A' * FuzzyLinkParser.maxPayloadLength;
        expect(FuzzyLinkGenerator.generateFuzzLink(_chatId, body), isNull);
      });

      test('a file, whose stored "message" is a path', () {
        expect(
          FuzzyLinkGenerator.generateFuzzLink(
            _chatId,
            'Fuzz//Users/someone/Documents/Bob/photo.jpg.fuzz',
          ),
          isNull,
        );
      });

      test('a chat id that is not a uuid', () {
        expect(
          FuzzyLinkGenerator.generateFuzzLink('chat', _messageBody),
          isNull,
        );
      });

      test('empty or non-base64url content', () {
        expect(FuzzyLinkGenerator.generateInvitationLink(''), isNull);
        expect(FuzzyLinkGenerator.generateInvitationLink('Fuzz/'), isNull);
        expect(
          FuzzyLinkGenerator.generateAcceptanceLink('Fuzz/ab+c/d='),
          isNull,
        );
      });
    });
  });
}
