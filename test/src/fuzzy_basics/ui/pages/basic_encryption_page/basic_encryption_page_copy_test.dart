import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

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

/// Basics shows an opened text but never lets it be selected or copied;
/// only a sealed result has a copy button (copy_guard).
void main() {
  late MockCryptoCoreService crypto;
  late _RecordingClipboard clipboard;
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('basic_encryption_page_copy_');
    sl.safeRegisterSingleton<UserFileStore>(
      UserFileStore(
        supportDirectoryPath: path.join(temp.path, 'support'),
        temporaryDirectoryPath: path.join(temp.path, 'tmp'),
        documentsDirectoryPath: path.join(temp.path, 'documents'),
      ),
    );
    crypto = MockCryptoCoreService();
    when(
      () => crypto.passwordSealText(
        password: any(named: 'password'),
        text: any(named: 'text'),
      ),
    ).thenAnswer((_) async => const CryptoCoreSuccess('SEALEDTEXT'));
    when(
      () => crypto.passwordOpenText(
        password: any(named: 'password'),
        blob: any(named: 'blob'),
      ),
    ).thenAnswer((_) async => const CryptoCoreSuccess('the opened secret'));
    sl.safeRegisterSingleton<CryptoCoreService>(crypto);
    sl.safeRegisterSingleton<PasswordStrengthService>(
      PasswordStrengthService(),
    );
    clipboard = _RecordingClipboard();
    CopyGuard.clipboardGuard = ClipboardGuard(clipboard: clipboard);
  });

  tearDown(() async {
    await sl.unregister<CryptoCoreService>();
    await sl.unregister<PasswordStrengthService>();
    CopyGuard.clipboardGuard = ClipboardGuard();
    await sl.unregister<UserFileStore>();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> pumpBasics(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: const BasicEncryptionPage(),
      ),
    );
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'key-12345');
    await tester.enterText(fields.last, 'some text');
  }

  final en = FuzzzyInkLocalizationsEn();
  final copyButton = find.byKey(const Key('btn.basics.copy_sealed'));

  testWidgets('a sealed result can be copied', (tester) async {
    await pumpBasics(tester);

    await tester.tap(find.text(en.encryptText));
    await tester.pumpAndSettle();

    expect(find.text('SEALEDTEXT'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(copyButton);
    await tester.pump();
    expect(clipboard.written, ['SEALEDTEXT']);

    await tester.pump(const Duration(seconds: 4));
    CopyGuard.clipboardGuard.dispose();
  });

  testWidgets('an opened result is neither selectable nor copyable',
      (tester) async {
    await pumpBasics(tester);

    await tester.tap(find.text(en.decryptText));
    await tester.pumpAndSettle();

    expect(find.text('the opened secret'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsNothing);
    expect(copyButton, findsNothing);
    await tester.longPress(find.text('the opened secret'));
    await tester.pumpAndSettle();
    expect(clipboard.written, isEmpty);
    CopyGuard.clipboardGuard.dispose();
  });
}
