import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockCryptoCoreService extends Mock implements CryptoCoreService {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

/// A row's stored path: relative to the app's sealed folder.
const _storedPath = 'chats/Fz bot (6f1e9b2c)/secret.jpg.fuzz';

/// The sealed folder the test store resolves rows against.
const _sealedRoot = '/app/support/sealed_files';
const _missingPath = '$_sealedRoot/$_storedPath';

/// A received program whose name hides its extension behind a direction
/// override: shown naively it reads "invoiceexe.pdf".
const _disguisedProgramPath =
    'chats/Bob (6f1e9b2c)/invoice\u{202E}fdp.exe.fuzz';

/// A 360dp-wide phone: every action of the pill must stay on it.
const _phoneSize = Size(360, 780);

/// `File.exists()` completes on the real event loop, which a widget test's
/// fake async never reaches; this stand-in answers within the test zone.
class _MissingFile extends Fake implements File {
  @override
  Future<bool> exists() async => false;
}

MessageData _fileRow({required bool isSent, String path = _storedPath}) =>
    MessageData(
      id: 1,
      chatId: _chatId,
      type: MessageType.file,
      encryptedMessage: path,
      decryptedMessage: '',
      sentAt: DateTime(2026, 9, 22, 12),
      isSent: isSent,
    );

Widget _host(Widget child) => MaterialApp(
      theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
      localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
      supportedLocales: FuzzzyInkLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider(
          create: (_) => ChatFileCubit(
            cryptoCoreService: _MockCryptoCoreService(),
            userFileStore: UserFileStore(
              supportDirectoryPath: '/app/support',
              temporaryDirectoryPath: '/app/tmp',
              documentsDirectoryPath: '/app/documents',
            ),
          ),
          child: child,
        ),
      ),
    );

/// Only the bubble's path is faked; the test binding keeps reading real
/// files (assets, fonts).
final class _MissingFileOverrides extends IOOverrides {
  @override
  File createFile(String path) =>
      path == _missingPath ? _MissingFile() : super.createFile(path);
}

Future<void> _withMissingFiles(Future<void> Function() body) =>
    IOOverrides.runWithIOOverrides(body, _MissingFileOverrides());

/// Tap the overlay's barrier so the action pill is closed before the tree is
/// torn down, then let the toast's auto-dismiss timer run out.
Future<void> _dismissOverlayAndToast(WidgetTester tester) async {
  await tester.tapAt(const Offset(1, 1));
  await tester.pump(const Duration(seconds: 4));
}

/// Every action of the open pill sits inside the phone's width.
void _expectPillOnScreen(WidgetTester tester) {
  final actions = find.byType(TextAction);
  expect(actions, findsAtLeastNWidgets(1));
  for (final action in actions.evaluate()) {
    final rect = tester.getRect(find.byWidget(action.widget));
    expect(rect.left, greaterThanOrEqualTo(0), reason: 'off the left edge');
    expect(
      rect.right,
      lessThanOrEqualTo(_phoneSize.width),
      reason: 'off the right edge',
    );
  }
}

void main() {
  setUp(() {
    // ignore: deprecated_member_use
    TestWidgetsFlutterBinding.instance.window.physicalSizeTestValue =
        _phoneSize;
    // ignore: deprecated_member_use
    TestWidgetsFlutterBinding.instance.window.devicePixelRatioTestValue = 1;
  });

  tearDown(() {
    // ignore: deprecated_member_use
    TestWidgetsFlutterBinding.instance.window.clearPhysicalSizeTestValue();
    // ignore: deprecated_member_use
    TestWidgetsFlutterBinding.instance.window.clearDevicePixelRatioTestValue();
  });

  // A file bubble names the file — never a path — and offers what the user
  // can do with the sealed file the app keeps. Nothing copies a path: the
  // old "Copy", link and "Copy as Link" actions put the local path (and the
  // user name in it) on the clipboard (security review).
  group('file bubble', () {
    testWidgets(
        'sent file: name + hint, Share File / Save only, all on a 360dp '
        'screen, a missing file toasts', (tester) async {
      await _withMissingFiles(() async {
        await tester.pumpWidget(
          _host(SentMessageArea(message: _fileRow(isSent: true))),
        );

        final en = FuzzzyInkLocalizationsEn();
        expect(find.text('secret.jpg'), findsOneWidget);
        expect(find.text(en.sentFileHint), findsOneWidget);
        expect(find.textContaining('/'), findsNothing);

        await tester.tap(find.text('secret.jpg'));
        await tester.pumpAndSettle();

        for (final label in [en.shareFile, en.saveFile]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        for (final gone in [en.show, en.copy, '🔗', en.copyAsLink]) {
          expect(find.text(gone), findsNothing, reason: gone);
        }
        _expectPillOnScreen(tester);

        await tester.tap(find.text(en.saveFile));
        await tester.pump();

        expect(find.text(en.couldNotSaveFile), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _dismissOverlayAndToast(tester);
      });
    });

    testWidgets(
        'received file: name + hint, Open / Save / Share File only, all on a '
        '360dp screen; a row the app cannot open toasts why', (tester) async {
      await tester.pumpWidget(
        _host(ReceivedFileMessageArea(message: _fileRow(isSent: false))),
      );

      final en = FuzzzyInkLocalizationsEn();
      expect(find.text('secret.jpg'), findsOneWidget);
      expect(find.text(en.receivedFileHint), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);

      await tester.tap(find.text('secret.jpg'));
      await tester.pumpAndSettle();

      for (final label in [en.open, en.saveFile, en.shareFile]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final gone in [en.show, en.copy, '🔗', en.copyAsLink]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      _expectPillOnScreen(tester);

      // The row carries no kept key: nothing is unfuzzed, the reason shows.
      await tester.tap(find.text(en.open));
      await tester.pumpAndSettle();

      expect(find.text(en.fileCorrupt), findsOneWidget);
      expect(find.byType(PlainFileViewerPage), findsNothing);
      expect(tester.takeException(), isNull);

      await _dismissOverlayAndToast(tester);
    });

    testWidgets("a sender's direction override cannot disguise the name",
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReceivedFileMessageArea(
            message: _fileRow(isSent: false, path: _disguisedProgramPath),
          ),
        ),
      );

      expect(find.text('invoicefdp.exe'), findsOneWidget);
      expect(find.textContaining('\u{202E}'), findsNothing);
    });
  });
}
