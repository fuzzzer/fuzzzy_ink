import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Records what the copy guard puts on the clipboard.
class _RecordingClipboard extends SecureClipboard {
  final written = <String>[];

  @override
  Future<void> write(
    String text, {
    required bool sensitive,
    required Duration clearAfter,
  }) async =>
      written.add(text);

  @override
  Future<ClipboardClearResult> clearIfStillOurs() async =>
      ClipboardClearResult.cleared;
}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

MessageData _textRow({required bool isSent}) => MessageData(
      id: 1,
      chatId: _chatId,
      type: MessageType.text,
      encryptedMessage: 'SEALEDBLOB',
      decryptedMessage: 'meet at noon',
      sentAt: DateTime(2026, 10, 26, 12),
      isSent: isSent,
    );

Widget _host(Widget child) => MaterialApp(
      theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
      localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
      supportedLocales: FuzzzyInkLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// Decrypted chat text is shown but never selectable or copyable; only the
/// sealed message the user sends is copied (copy_guard).
void main() {
  late _RecordingClipboard clipboard;

  setUp(() {
    clipboard = _RecordingClipboard();
    CopyGuard.clipboardGuard = ClipboardGuard(clipboard: clipboard);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('vibration'),
      (_) async => false,
    );
  });

  tearDown(() {
    CopyGuard.clipboardGuard = ClipboardGuard();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('vibration'), null);
  });

  testWidgets('a received message is plain text: no selection, no copy',
      (tester) async {
    await tester.pumpWidget(
      _host(ReceivedTextMessageArea(message: _textRow(isSent: false))),
    );

    expect(find.text('meet at noon'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsNothing);

    await tester.longPress(find.text('meet at noon'));
    await tester.pumpAndSettle();
    expect(clipboard.written, isEmpty);
    expect(find.text('Copy'), findsNothing);
    CopyGuard.clipboardGuard.dispose();
  });

  testWidgets(
      'a sent message copies only its sealed form, also while the '
      'decrypted text is shown', (tester) async {
    await tester.pumpWidget(
      _host(SentMessageArea(message: _textRow(isSent: true))),
    );

    // Swipe to show the decrypted text: still not selectable.
    await tester.drag(find.text('SEALEDBLOB'), const Offset(-60, 0));
    await tester.pump();
    expect(find.text('meet at noon'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);

    await tester.longPress(find.text('meet at noon'));
    await tester.pump();
    expect(clipboard.written, ['${fuzzIdentificator}SEALEDBLOB']);

    await tester.pump(const Duration(seconds: 4));
    CopyGuard.clipboardGuard.dispose();
  });
}
