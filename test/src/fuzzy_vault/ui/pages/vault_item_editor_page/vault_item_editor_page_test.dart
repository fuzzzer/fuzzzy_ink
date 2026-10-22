import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class _FakeFilePicker extends FilePicker {
  @override
  Future<bool?> clearTemporaryFiles() async => true;
}

/// "Open" on a vault file that could run (a program, script or shortcut)
/// explains itself in the app's language, like a chat does, instead of
/// showing a raw error.
void main() {
  late Directory temp;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    temp = Directory.systemTemp.createTempSync('vault_item_editor_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProvider, (_) async => temp.path);
    FilePicker.platform = _FakeFilePicker();
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathProvider, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  VaultItem fileItem(String fileName) => VaultItem(
        metadata: VaultItemMetadata(
          id: 'item-1',
          title: fileName,
          type: VaultItemType.file,
          groupId: 'general',
          tags: const [],
          isFavorite: false,
          hasCustomPassword: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          contentVersion: 1,
        ),
        fileContent: VaultFileContent(fileName: fileName, fileBytes: [1, 2]),
      );

  testWidgets('a risky file shows the localized risky-file dialog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: VaultItemEditorPage(
          payload: VaultItemEditorPagePayload(
            type: VaultItemType.file,
            existingItem: fileItem('setup.exe'),
          ),
        ),
      ),
    );
    await tester.pump();

    final en = FuzzzyInkLocalizationsEn();
    await tester.runAsync(() async {
      await tester.tap(find.text(en.open));
      // The temporary copy is written with real file I/O.
      for (var i = 0;
          i < 20 && find.byType(AlertDialog).evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.text(en.riskyFileNotOpenedTitle), findsOneWidget);
    expect(
      find.text(en.riskyFileNotOpenedMessage('setup.exe')),
      findsOneWidget,
    );
    expect(find.textContaining('RiskyFileOpenRefused'), findsNothing);
    expect(
      find.byKey(const ValueKey('riskyFileDialog.showInFolder')),
      findsOneWidget,
    );
  });
}
