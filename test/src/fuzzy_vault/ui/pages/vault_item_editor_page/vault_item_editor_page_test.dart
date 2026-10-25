import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:path/path.dart' as path;

class _FakeFilePicker extends FilePicker {
  @override
  Future<bool?> clearTemporaryFiles() async => true;
}

/// "Open" on a vault file shows it inside the app, from memory: no plain
/// copy is written, and a file the app cannot show (a program, a PDF) offers
/// Save only — the app never hands it to another app to open.
void main() {
  late Directory temp;
  late UserFileStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('vault_item_editor_');
    FilePicker.platform = _FakeFilePicker();
    store = UserFileStore(
      supportDirectoryPath: path.join(temp.path, 'support'),
      temporaryDirectoryPath: path.join(temp.path, 'tmp'),
      documentsDirectoryPath: path.join(temp.path, 'documents'),
    );
    sl.safeRegisterSingleton<UserFileStore>(store);
  });

  tearDown(() async {
    await sl.unregister<UserFileStore>();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  VaultItem fileItem(String fileName, List<int> bytes) => VaultItem(
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
        fileContent: VaultFileContent(fileName: fileName, fileBytes: bytes),
      );

  Future<void> openItem(WidgetTester tester, VaultItem item) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: VaultItemEditorPage(
          payload: VaultItemEditorPagePayload(
            type: VaultItemType.file,
            existingItem: item,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(FuzzzyInkLocalizationsEn().open));
    await tester.pumpAndSettle();
  }

  testWidgets('a text file is shown in the app, and nothing is written',
      (tester) async {
    await openItem(tester, fileItem('note.txt', utf8.encode('the secret')));

    expect(find.byType(PlainFileViewerPage), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('the secret'), findsOneWidget);
    expect(Directory(store.handoffRootPath).existsSync(), isFalse);
  });

  testWidgets('a program is not shown or run: the viewer offers Save only',
      (tester) async {
    await openItem(tester, fileItem('setup.exe', [0x4D, 0x5A]));

    final en = FuzzzyInkLocalizationsEn();
    expect(find.byType(PlainFileViewerPage), findsOneWidget);
    expect(find.text(en.fileNoPreview), findsOneWidget);
    expect(find.text(en.saveFile), findsWidgets);
    expect(Directory(store.handoffRootPath).existsSync(), isFalse);
  });
}
