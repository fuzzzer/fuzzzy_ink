import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

/// Opaque blob bodies (base64url, no padding) as the core writes them after
/// `Fuzz/`; the link never looks inside. 271 characters, like a real
/// invitation.
final _invitationBody = 'RlVaWgEB${'A' * 263}';
final _acceptanceBody = 'RlVaWgEC${'B' * 600}';
const _messageBody = 'RlVaWgEDAQ-_xyz09';

/// As long as a real message: every real locked part is longer than a
/// wrapped line can be.
final _realMessageBody = 'RlVaWgEDAQ${'C' * 190}';
const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _base = 'https://ink.fuzzzycore.com';

FuzzyLinkPayload? _parse(String link) => FuzzyLinkParser.parse(Uri.parse(link));

/// [text] broken every [width] characters with [separator], as a mail
/// program wraps a long line.
String _wrap(String text, int width, String separator) => [
      for (var i = 0; i < text.length; i += width)
        text.substring(i, i + width > text.length ? text.length : i + width),
    ].join(separator);

void main() {
  group('FuzzyLinkParser accepts exactly the three link kinds', () {
    test('an invitation link gives the Fuzz/ invitation back', () {
      final payload = _parse('$_base/invite#$_invitationBody');

      expect(payload, isA<InvitationLinkPayload>());
      final typed = payload! as InvitationLinkPayload;
      expect(typed.type, FuzzyLinkType.invitation);
      expect(typed.rawInvitationContent, 'Fuzz/$_invitationBody');
    });

    test('an acceptance link gives the Fuzz/ acceptance back', () {
      final payload = _parse('$_base/accept#$_acceptanceBody');

      expect(payload, isA<AcceptanceLinkPayload>());
      final typed = payload! as AcceptanceLinkPayload;
      expect(typed.type, FuzzyLinkType.acceptance);
      expect(typed.rawAcceptanceContent, 'Fuzz/$_acceptanceBody');
    });

    test('a message link gives the stored blob back, and nothing else', () {
      final payload = _parse('$_base/message#$_messageBody');

      expect(payload, isA<FuzzMessageLinkPayload>());
      final typed = payload! as FuzzMessageLinkPayload;
      expect(typed.type, FuzzyLinkType.message);
      expect(typed.encryptedMessage, _messageBody);
    });

    // Dart's Uri, like the OS, reads these as the very same address: the
    // default port and an escaped letter are normalised away.
    test('the default port and escaped unreserved letters are the same link',
        () {
      expect(
        _parse('https://ink.fuzzzycore.com:443/invite#$_invitationBody'),
        isA<InvitationLinkPayload>(),
      );
      expect(
        _parse('$_base/invite#%52lVaWgEB'),
        isA<InvitationLinkPayload>(),
      );
    });

    test('the host is case-insensitive, as it is for the OS', () {
      expect(
        _parse('https://INK.FuzzzyCore.com/invite#$_invitationBody'),
        isA<InvitationLinkPayload>(),
      );
    });
  });

  group('FuzzyLinkParser refuses', () {
    final refused = <String, String>{
      // Fragment only, or no fragment.
      'a bare fragment': '#$_invitationBody',
      'a fragment on the bare host': '$_base#$_invitationBody',
      'a fragment on the root path': '$_base/#$_invitationBody',
      'an empty fragment': '$_base/invite#',
      'no fragment': '$_base/invite',
      'the payload in the path': '$_base/invite/$_invitationBody',
      'the payload in a query': '$_base/invite?b=$_invitationBody',
      // Scheme and host.
      'the old fuzzylink scheme': 'fuzzylink://invite#$_invitationBody',
      'http': 'http://ink.fuzzzycore.com/invite#$_invitationBody',
      'another host': 'https://evil.example/invite#$_invitationBody',
      'a look-alike host':
          'https://ink.fuzzzycore.com.evil.example/invite#$_invitationBody',
      'a sub-domain': 'https://x.ink.fuzzzycore.com/invite#$_invitationBody',
      'the parent domain': 'https://fuzzzycore.com/invite#$_invitationBody',
      'a port': 'https://ink.fuzzzycore.com:8443/invite#$_invitationBody',
      'user info': 'https://me@ink.fuzzzycore.com/invite#$_invitationBody',
      'an empty query': '$_base/invite?#$_invitationBody',
      'a query': '$_base/invite?utm=x#$_invitationBody',
      // Path.
      'a trailing slash': '$_base/invite/#$_invitationBody',
      'another case': '$_base/Invite#$_invitationBody',
      'an unknown kind': '$_base/file#$_invitationBody',
      'a deeper path': '$_base/x/invite#$_invitationBody',
      // Payload.
      'the Fuzz/ prefix inside': '$_base/invite#Fuzz/$_invitationBody',
      'base64 padding': '$_base/invite#${_invitationBody}A=',
      'standard base64 characters': '$_base/invite#ab+cd',
      'an escaped "+"': '$_base/invite#ab%2Bcd',
      'an escaped space': '$_base/invite#ab%20cd',
      'a dot in a pairing payload': '$_base/accept#$_chatId.$_messageBody',
      // The old shape with a chat id in the clear is gone (security review
      // 2026-10-26): pre-launch, no link was ever made with it.
      'a message with a chat id': '$_base/message#$_chatId.$_messageBody',
      'a message with a dot': '$_base/message#$_messageBody.x',
    };

    for (final MapEntry(key: reason, value: link) in refused.entries) {
      test(reason, () {
        final uri = Uri.tryParse(link);
        // A link Dart cannot even parse never reaches the parser.
        if (uri != null) expect(FuzzyLinkParser.parse(uri), isNull);
      });
    }
  });

  group('FuzzyLinkParser size limit', () {
    test('a fragment of exactly the limit is accepted', () {
      final body = 'A' * FuzzyLinkParser.maxPayloadLength;
      expect(_parse('$_base/invite#$body'), isA<InvitationLinkPayload>());
    });

    test('one character over the limit is refused', () {
      final body = 'A' * (FuzzyLinkParser.maxPayloadLength + 1);
      expect(_parse('$_base/invite#$body'), isNull);
    });

    test('an oversized message link is refused', () {
      final body = 'A' * (FuzzyLinkParser.maxPayloadLength + 1);
      expect(_parse('$_base/message#$body'), isNull);
    });
  });

  group('FuzzyLinkParser.parseText (a pasted link)', () {
    test('surrounding whitespace and new lines are ignored', () {
      expect(
        FuzzyLinkParser.parseText('\n  $_base/invite#$_invitationBody \n'),
        isA<InvitationLinkPayload>(),
      );
    });

    test('a link inside other text is refused', () {
      expect(
        FuzzyLinkParser.parseText('Open this: $_base/invite#$_invitationBody'),
        isNull,
      );
    });

    test('a link broken by a line wrap is refused', () {
      expect(
        FuzzyLinkParser.parseText('$_base/invite#RlVa\nWgEB'),
        isNull,
      );
    });

    test('empty text is refused', () {
      expect(FuzzyLinkParser.parseText('   '), isNull);
    });
  });

  group('FuzzyLinkParser.blobFromPastedLink', () {
    test('a link of the asked kind gives its Fuzz/ blob', () {
      expect(
        FuzzyLinkParser.blobFromPastedLink(
          '$_base/accept#$_acceptanceBody',
          FuzzyLinkType.acceptance,
        ),
        'Fuzz/$_acceptanceBody',
      );
      expect(
        FuzzyLinkParser.blobFromPastedLink(
          '$_base/message#$_messageBody',
          FuzzyLinkType.message,
        ),
        'Fuzz/$_messageBody',
      );
    });

    test('a link of another kind is left alone', () {
      expect(
        FuzzyLinkParser.blobFromPastedLink(
          '$_base/invite#$_invitationBody',
          FuzzyLinkType.acceptance,
        ),
        isNull,
      );
    });

    test('a pasted blob or plain text is left alone', () {
      expect(
        FuzzyLinkParser.blobFromPastedLink(
          'Fuzz/$_invitationBody',
          FuzzyLinkType.invitation,
        ),
        isNull,
      );
      expect(
        FuzzyLinkParser.blobFromPastedLink('hello', FuzzyLinkType.message),
        isNull,
      );
    });
  });

  group('FuzzyLinkParser.findIn (the locked part of a longer text)', () {
    test('finds a link or a Fuzz/ text among other words', () {
      expect(
        FuzzyLinkParser.findIn(
          'Nino: here (https://ink.fuzzzycore.com/message#$_messageBody). Bye',
        ),
        '$_base/message#$_messageBody',
      );
      expect(
        FuzzyLinkParser.findIn('read this:\n"Fuzz/AwEC-_x".'),
        'Fuzz/AwEC-_x',
      );
      expect(FuzzyLinkParser.findIn('  Fuzz/AwEC  '), 'Fuzz/AwEC');
    });

    test('keeps the base64url ends of the locked part', () {
      expect(FuzzyLinkParser.findIn('Fuzz/AwE-'), 'Fuzz/AwE-');
      expect(FuzzyLinkParser.findIn('Fuzz/AwE_,'), 'Fuzz/AwE_');
    });

    test('finds nothing in text with nothing locked', () {
      expect(FuzzyLinkParser.findIn(''), isNull);
      expect(FuzzyLinkParser.findIn('my bank password is 1234'), isNull);
      expect(FuzzyLinkParser.findIn('Fuzz/'), isNull);
      expect(FuzzyLinkParser.findIn('Fuzz/a+b='), isNull);
      expect(
        FuzzyLinkParser.findIn('https://example.com/message#AwEC'),
        isNull,
      );
    });

    test('finds a link glued to a word, in any script', () {
      final link = '$_base/message#$_realMessageBody';
      expect(FuzzyLinkParser.findIn('Here it is:$link thanks'), link);
      expect(FuzzyLinkParser.findIn('[open it]($link)'), link);
      expect(FuzzyLinkParser.findIn('ბმული:$link მადლობა'), link);
      expect(FuzzyLinkParser.findIn('see:Fuzz/AwEC-_x.'), 'Fuzz/AwEC-_x');
    });

    test('joins a Fuzz/ text wrapped every 76 characters, once', () {
      final fuzz = 'Fuzz/$_invitationBody';
      for (final separator in ['\n', '\r\n', ' ']) {
        final wrapped = _wrap(fuzz, 76, separator);
        expect(wrapped.contains(separator), isTrue);
        expect(FuzzyLinkParser.findIn(wrapped), fuzz);
        expect(FuzzyLinkParser.findAll('Hi,\n\n$wrapped\n\nBye'), [fuzz]);
      }
    });

    test('joins a wrapped Fuzz/ text that starts after other words', () {
      final fuzz = 'Fuzz/$_invitationBody';
      final line = 'Here it is: $fuzz';
      final wrapped = _wrap(line, 72, '\n');
      expect(FuzzyLinkParser.findIn(wrapped), fuzz);
    });

    test('joins a wrapped link', () {
      final link = '$_base/invite#$_invitationBody';
      expect(FuzzyLinkParser.findIn(_wrap(link, 76, '\n')), link);
    });

    test('never joins the word after an unwrapped locked part', () {
      final fuzz = 'Fuzz/$_invitationBody';
      expect(FuzzyLinkParser.findIn('$fuzz thanks'), fuzz);
      expect(FuzzyLinkParser.findIn('$fuzz\nthanks'), fuzz);
      expect(FuzzyLinkParser.findIn('Fuzz/AwEC thanks'), 'Fuzz/AwEC');
      // A wrapped one ends at its short last line.
      final wrapped = _wrap(fuzz, 76, '\n');
      expect(FuzzyLinkParser.findIn('$wrapped\nthanks a lot'), fuzz);
    });

    test('finds every locked part, each once', () {
      final link = '$_base/message#$_realMessageBody';
      final invite = '$_base/invite#$_invitationBody';
      expect(
        FuzzyLinkParser.findAll('first $invite then $link and $link again'),
        [invite, link],
      );
      expect(FuzzyLinkParser.findAll('nothing here'), isEmpty);
    });
  });

  group('FuzzyLinkType.fromPath', () {
    test('knows the three paths and nothing else', () {
      expect(FuzzyLinkType.fromPath('/invite'), FuzzyLinkType.invitation);
      expect(FuzzyLinkType.fromPath('/accept'), FuzzyLinkType.acceptance);
      expect(FuzzyLinkType.fromPath('/message'), FuzzyLinkType.message);
      expect(FuzzyLinkType.fromPath('/'), isNull);
      expect(FuzzyLinkType.fromPath('/chat/accept'), isNull);
      expect(FuzzyLinkType.fromPath('invite'), isNull);
    });
  });
}
