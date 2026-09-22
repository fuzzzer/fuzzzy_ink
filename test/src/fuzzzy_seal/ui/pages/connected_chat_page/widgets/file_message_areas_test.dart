import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _missingPath =
    '/storage/emulated/0/Download/Fuzzzy Seal/Fz bot/secret.jpg.fuzz';

/// A 360dp-wide phone (T-0366: every action of the pill must stay on it).
const _phoneSize = Size(360, 780);

/// `File.exists()` completes on the real event loop, which a widget test's
/// fake async never reaches; this stand-in answers within the test zone.
class _MissingFile extends Fake implements File {
  @override
  Future<bool> exists() async => false;

  @override
  Directory get parent => Directory('/storage/emulated/0/Download/Fuzzzy Seal');
}

MessageData _fileRow({required bool isSent}) => MessageData(
      id: 1,
      chatId: _chatId,
      type: MessageType.file,
      encryptedMessage: _missingPath,
      decryptedMessage: '',
      sentAt: DateTime(2026, 9, 22, 12),
      isSent: isSent,
    );

Widget _host(Widget child) => MaterialApp(
      theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
      localizationsDelegates: FuzzzySealLocalizations.localizationsDelegates,
      supportedLocales: FuzzzySealLocalizations.supportedLocales,
      home: Scaffold(body: child),
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

  // T-0366: a file bubble names the file and the folder the user finds it
  // in — never a path — its pill offers "Show" on every platform and fits a
  // 360dp phone, and a failing action surfaces a toast instead of an
  // unhandled error. The test host is desktop, so "Show" selects the file in
  // the file manager, which a missing file cannot do.
  group('file bubble (T-0366)', () {
    testWidgets(
        'sent file: name + location, Show / Share File / Copy / link actions '
        'all on a 360dp screen, a missing file toasts', (tester) async {
      await _withMissingFiles(() async {
        await tester.pumpWidget(
          _host(SentMessageArea(message: _fileRow(isSent: true))),
        );

        expect(find.text('secret.jpg.fuzz'), findsOneWidget);
        expect(find.text('Downloads › Fuzzzy Seal › Fz bot'), findsOneWidget);
        expect(find.textContaining('/storage/'), findsNothing);

        await tester.tap(find.text('secret.jpg.fuzz'));
        await tester.pumpAndSettle();

        for (final label in [
          'Show',
          'Share File',
          'Copy',
          '🔗',
          'Copy as Link',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        _expectPillOnScreen(tester);

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text('Could not open file.'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _dismissOverlayAndToast(tester);
      });
    });

    testWidgets(
        'received file: name + location, Show / Open / Share File / link / '
        'Copy actions all on a 360dp screen, "Open" on a missing file toasts',
        (tester) async {
      await _withMissingFiles(() async {
        await tester.pumpWidget(
          _host(ReceivedFileMessageArea(message: _fileRow(isSent: false))),
        );

        expect(find.text('secret.jpg.fuzz'), findsOneWidget);
        expect(find.text('Downloads › Fuzzzy Seal › Fz bot'), findsOneWidget);
        expect(find.textContaining('/storage/'), findsNothing);

        await tester.tap(find.text('secret.jpg.fuzz'));
        await tester.pumpAndSettle();

        for (final label in [
          'Show',
          'Open',
          'Share File',
          '🔗',
          'Copy as Link',
          'Copy',
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        _expectPillOnScreen(tester);

        await tester.tap(find.text('Open'));
        await tester.pump();

        expect(find.text('Could not open file.'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _dismissOverlayAndToast(tester);
      });
    });
  });
}
