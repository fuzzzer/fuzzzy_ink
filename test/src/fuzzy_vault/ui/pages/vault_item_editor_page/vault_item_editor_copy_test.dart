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

/// Records what the copy guard puts on the clipboard.
class _RecordingClipboard extends SecureClipboard {
  final written = <({String text, bool sensitive})>[];

  @override
  Future<void> write(
    String text, {
    required bool sensitive,
    required Duration clearAfter,
  }) async =>
      written.add((text: text, sensitive: sensitive));

  @override
  Future<ClipboardClearResult> clearIfStillOurs() async =>
      ClipboardClearResult.cleared;
}

VaultItem _passwordItem() => VaultItem(
      metadata: VaultItemMetadata(
        id: 'item-1',
        title: 'Bank',
        type: VaultItemType.password,
        groupId: 'general',
        tags: const [],
        isFavorite: false,
        hasCustomPassword: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        contentVersion: 1,
      ),
      passwordContent: const VaultPasswordContent(
        username: 'nino@example.com',
        password: 'hunter2',
        notes: 'pin is under the plant',
      ),
    );

/// An opened vault item's text can be edited and pasted into, but never
/// selected out of the app; only the password has a copy button, and its
/// copy is sensitive (copy_guard).
void main() {
  late _RecordingClipboard clipboard;
  late Directory temp;

  setUp(() {
    FilePicker.platform = _FakeFilePicker();
    temp = Directory.systemTemp.createTempSync('vault_item_editor_copy_');
    sl.safeRegisterSingleton<UserFileStore>(
      UserFileStore(
        supportDirectoryPath: path.join(temp.path, 'support'),
        temporaryDirectoryPath: path.join(temp.path, 'tmp'),
        documentsDirectoryPath: path.join(temp.path, 'documents'),
      ),
    );
    clipboard = _RecordingClipboard();
    CopyGuard.clipboardGuard = ClipboardGuard(clipboard: clipboard);
  });

  tearDown(() async {
    CopyGuard.clipboardGuard = ClipboardGuard();
    await sl.unregister<UserFileStore>();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: VaultItemEditorPage(
          payload: VaultItemEditorPagePayload(
            type: VaultItemType.password,
            existingItem: _passwordItem(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('every opened field refuses copy, cut and share', (tester) async {
    await pumpEditor(tester);

    expect(find.byType(SelectableText), findsNothing);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(4), reason: 'username, password, address, notes');
    for (final field in fields) {
      expect(
        field.contextMenuBuilder,
        CopyGuard.plaintextContextMenuBuilder,
        reason: field.controller?.text,
      );
    }
    CopyGuard.clipboardGuard.dispose();
  });

  testWidgets('a long press on the note offers no copy',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await pumpEditor(tester);

    // Long-press the first word, so there is a selection to copy.
    final note = find.text('pin is under the plant');
    await tester.longPressAt(tester.getTopLeft(note) + const Offset(8, 8));
    await tester.pumpAndSettle();

    final noteField = tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(noteField.controller!.selection.isCollapsed, isFalse);
    expect(find.text('Select all'), findsOneWidget, reason: 'menu is open');
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(clipboard.written, isEmpty);

    CopyGuard.clipboardGuard.dispose();
  });

  testWidgets('the password copy button copies it as sensitive',
      (tester) async {
    await pumpEditor(tester);

    final button = find.byKey(const Key('vault.copy_password'));
    expect(button, allowVaultPasswordCopy ? findsOneWidget : findsNothing);
    if (allowVaultPasswordCopy) {
      await tester.tap(button);
      await tester.pump();
      expect(clipboard.written.single, (text: 'hunter2', sensitive: true));
      expect(
        find.text(
          FuzzzyInkLocalizationsEn().vaultPasswordCopiedClearsIn(30),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    }
    CopyGuard.clipboardGuard.dispose();
  });
}
