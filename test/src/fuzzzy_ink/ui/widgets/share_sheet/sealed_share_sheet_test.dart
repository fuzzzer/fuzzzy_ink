import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

final _invitation = 'Fuzz/RlVaWgEB${'A' * 263}';
const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

/// Records what the guard writes instead of touching the system clipboard.
class _FakeSecureClipboard extends SecureClipboard {
  final writes = <String>[];

  @override
  Future<void> write(
    String text, {
    required bool sensitive,
    required Duration clearAfter,
  }) async =>
      writes.add(text);

  @override
  Future<ClipboardClearResult> clearIfStillOurs() async =>
      ClipboardClearResult.cleared;
}

Widget _host(
  SealedShareContent content, {
  String? personName,
  void Function(SealedShareResult?)? onResult,
}) =>
    MaterialApp(
      theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
      localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
      supportedLocales: FuzzzyInkLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showSealedShareSheet(
                context,
                content: content,
                personName: personName,
              );
              onResult?.call(result);
            },
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
    testWidgets(
        'an invitation: "Share invite", any way, link, QR code, file and '
        'copy as text', (tester) async {
      await tester
          .pumpWidget(_host(SealedShareContent.invitation(_invitation)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Share invite'), findsOneWidget);
      expect(find.text('Any way. Even publicly.'), findsOneWidget);
      expect(find.text('Send a link'), findsOneWidget);
      expect(find.text('Show a QR code'), findsOneWidget);
      expect(
        find.text('Send as a file'),
        ShareHelper.canShareFiles ? findsOneWidget : findsNothing,
      );
      expect(find.text('Copy as text'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a message names who can open it', (tester) async {
      await tester.pumpWidget(
        _host(
          SealedShareContent.message(
            chatId: _chatId,
            encryptedMessage: 'RlVaWgED',
          ),
          personName: 'Nino',
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Share locked message'), findsOneWidget);
      expect(find.text('Only Nino can open it.'), findsOneWidget);
    });

    testWidgets('without a link: no link row, the QR row is off and says why',
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

      expect(find.text('Send a link'), findsNothing);
      expect(find.text('Too big. Send it as a file.'), findsOneWidget);

      // The QR row is off: tapping it changes nothing.
      await tester.tap(find.text('Show a QR code'));
      await tester.pumpAndSettle();
      expect(find.byType(QrCodeView), findsNothing);
      expect(find.text('Show a QR code'), findsOneWidget);
    });

    testWidgets(
        'the QR code option closes the sheet and shows the code full screen',
        (tester) async {
      SealedShareResult? result;
      await tester.pumpWidget(
        _host(
          SealedShareContent.invitation(_invitation),
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show a QR code'));
      await tester.pumpAndSettle();

      expect(find.text('Send a link'), findsNothing);
      expect(find.byType(QrCodeView), findsOneWidget);
      expect(find.byType(InkMark), findsOneWidget);
      expect(
        find.text('Safe to show anyone. Only their reply connects you.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(QrCodeView), findsNothing);
      expect(result?.action, SealedShareAction.qrCode);
    });

    testWidgets(
        'copy as text copies only the locked text, confirms in its row, then '
        'closes the sheet', (tester) async {
      final clipboard = _FakeSecureClipboard();
      final previous = CopyGuard.clipboardGuard;
      final guard = ClipboardGuard(clipboard: clipboard);
      CopyGuard.clipboardGuard = guard;
      addTearDown(() => CopyGuard.clipboardGuard = previous);
      SealedShareResult? result;

      await tester.pumpWidget(
        _host(
          SealedShareContent.invitation(_invitation),
          onResult: (r) => result = r,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy as text'));
      await tester.pump();
      expect(clipboard.writes, [_invitation]);
      expect(find.text('Copied. It stays locked.'), findsOneWidget);
      expect(find.text('Copy as text'), findsNothing);

      await tester.pump(InkMotionTiming.sheetCloseAfterCopy);
      await tester.pumpAndSettle();
      expect(find.text('Share invite'), findsNothing);
      expect(result?.action, SealedShareAction.copied);
      expect(result?.isDone, isTrue);

      // The clipboard's own clear timer belongs to the guard.
      guard.dispose();
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
