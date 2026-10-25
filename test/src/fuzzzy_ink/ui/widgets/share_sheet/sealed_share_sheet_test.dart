import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

final _invitation = 'Fuzz/RlVaWgEB${'A' * 263}';
const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

Widget _host(SealedShareContent content) => MaterialApp(
      theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
      localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
      supportedLocales: FuzzzyInkLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSealedShareSheet(context, content: content),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  group('SealedShareContent', () {
    test('an invitation offers its https link and a QR code', () {
      final content = SealedShareContent.invitation(_invitation);

      expect(content.link, startsWith('https://ink.fuzzzycore.com/invite#'));
      expect(content.canShowQrCode, isTrue);
      expect(content.sealedText, _invitation);
    });

    test('a message shares the Fuzz/ text, its link names the chat', () {
      final content = SealedShareContent.message(
        chatId: _chatId,
        encryptedMessage: 'RlVaWgED',
      );

      expect(content.sealedText, 'Fuzz/RlVaWgED');
      expect(
        content.link,
        'https://ink.fuzzzycore.com/message#$_chatId.RlVaWgED',
      );
    });

    test('a link too long for a QR code still goes as a link', () {
      final content = SealedShareContent.message(
        chatId: _chatId,
        encryptedMessage: 'A' * 2000,
      );

      expect(content.link, isNotNull);
      expect(content.canShowQrCode, isFalse);
    });

    test('a message too long for a link goes only as a file', () {
      final content = SealedShareContent.message(
        chatId: _chatId,
        encryptedMessage: 'A' * FuzzyLinkParser.maxPayloadLength,
      );

      expect(content.link, isNull);
      expect(content.canShowQrCode, isFalse);
    });
  });

  group('showSealedShareSheet', () {
    testWidgets('offers link, QR code and file for an invitation',
        (tester) async {
      await tester
          .pumpWidget(_host(SealedShareContent.invitation(_invitation)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Send as a link'), findsOneWidget);
      expect(find.text('Show a QR code'), findsOneWidget);
      expect(
        find.text('Send as a file'),
        ShareHelper.canShareFiles ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers neither link nor QR code when there is no link',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SealedShareContent.message(
            chatId: _chatId,
            encryptedMessage: 'A' * FuzzyLinkParser.maxPayloadLength,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Send as a link'), findsNothing);
      expect(find.text('Show a QR code'), findsNothing);
    });

    testWidgets('the QR code option closes the sheet and shows the code',
        (tester) async {
      await tester
          .pumpWidget(_host(SealedShareContent.invitation(_invitation)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show a QR code'));
      await tester.pumpAndSettle();

      expect(find.text('Send as a link'), findsNothing);
      expect(find.byType(QrCodeView), findsOneWidget);
      expect(find.textContaining("other phone's camera"), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(QrCodeView), findsNothing);
    });
  });

  testWidgets('QrCodeView draws even the longest link a QR code is offered for',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        home: Center(
          child: SizedBox(
            width: 300,
            child: QrCodeView(
              data: 'https://ink.fuzzzycore.com/message#'
                  '${'A' * (SealedShareContent.maxQrCodeLinkLength - 35)}',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(QrCodeView)), const Size(300, 300));
  });
}
