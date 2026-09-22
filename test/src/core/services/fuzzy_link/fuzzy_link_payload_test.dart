import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

void main() {
  group('FuzzyLinkPayload', () {
    group('version support', () {
      test('current version is supported', () {
        const payload = FuzzMessageLinkPayload(
          version: FuzzyLinkPayload.currentVersion,
          chatId: 'test',
          encryptedMessage: 'msg',
        );
        expect(payload.isSupported, isTrue);
      });

      test('older version is supported', () {
        const payload = FuzzMessageLinkPayload(
          version: 1,
          chatId: 'test',
          encryptedMessage: 'msg',
        );
        expect(payload.isSupported, isTrue);
      });

      test('future version is not supported', () {
        const payload = FuzzMessageLinkPayload(
          version: FuzzyLinkPayload.currentVersion + 1,
          chatId: 'test',
          encryptedMessage: 'msg',
        );
        expect(payload.isSupported, isFalse);
      });
    });

    group('InvitationLinkPayload expiration', () {
      test('non-expired link returns false', () {
        final futureExp = DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = InvitationLinkPayload(
          version: 1,
          rawInvitationContent: 'Fuzz/RlVaWgEB',
          expiresAt: futureExp,
        );
        expect(payload.isExpired, isFalse);
      });

      test('expired link returns true', () {
        final pastExp = DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = InvitationLinkPayload(
          version: 1,
          rawInvitationContent: 'Fuzz/RlVaWgEB',
          expiresAt: pastExp,
        );
        expect(payload.isExpired, isTrue);
      });

      test('null expiration returns false', () {
        const payload = InvitationLinkPayload(
          version: 1,
          rawInvitationContent: 'Fuzz/RlVaWgEB',
          expiresAt: null,
        );
        expect(payload.isExpired, isFalse);
      });
    });

    group('AcceptanceLinkPayload expiration', () {
      test('non-expired link returns false', () {
        final futureExp = DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = AcceptanceLinkPayload(
          version: 1,
          rawAcceptanceContent: 'Fuzz/RlVaWgEC',
          expiresAt: futureExp,
        );
        expect(payload.isExpired, isFalse);
      });

      test('expired link returns true', () {
        final pastExp = DateTime.now()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = AcceptanceLinkPayload(
          version: 1,
          rawAcceptanceContent: 'Fuzz/RlVaWgEC',
          expiresAt: pastExp,
        );
        expect(payload.isExpired, isTrue);
      });
    });

    group('FuzzyLinkType', () {
      test('fromUriSegment resolves all types', () {
        expect(
          FuzzyLinkType.fromUriSegment('invite'),
          FuzzyLinkType.invitation,
        );
        expect(
          FuzzyLinkType.fromUriSegment('accept'),
          FuzzyLinkType.acceptance,
        );
        expect(FuzzyLinkType.fromUriSegment('fuzz'), FuzzyLinkType.fuzz);
      });

      test('fromUriSegment returns null for unknown', () {
        expect(FuzzyLinkType.fromUriSegment('unknown'), isNull);
        expect(FuzzyLinkType.fromUriSegment(''), isNull);
      });

      test('fromPayloadCode resolves all types', () {
        expect(FuzzyLinkType.fromPayloadCode('inv'), FuzzyLinkType.invitation);
        expect(FuzzyLinkType.fromPayloadCode('acc'), FuzzyLinkType.acceptance);
        expect(FuzzyLinkType.fromPayloadCode('fuz'), FuzzyLinkType.fuzz);
      });

      test('fromPayloadCode returns null for unknown', () {
        expect(FuzzyLinkType.fromPayloadCode('xyz'), isNull);
        expect(FuzzyLinkType.fromPayloadCode(''), isNull);
      });

      test('payload type has correct mapping', () {
        expect(FuzzyLinkType.invitation.uriSegment, 'invite');
        expect(FuzzyLinkType.invitation.payloadCode, 'inv');
        expect(FuzzyLinkType.acceptance.uriSegment, 'accept');
        expect(FuzzyLinkType.acceptance.payloadCode, 'acc');
        expect(FuzzyLinkType.fuzz.uriSegment, 'fuzz');
        expect(FuzzyLinkType.fuzz.payloadCode, 'fuz');
      });
    });
  });
}
