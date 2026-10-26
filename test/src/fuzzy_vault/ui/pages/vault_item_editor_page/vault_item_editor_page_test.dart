import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../../../helpers/redesign_harness.dart';

class _FakeFilePicker extends FilePicker {
  @override
  Future<bool?> clearTemporaryFiles() async => true;
}

class MockVaultRepository extends Mock implements VaultRepository {}

class MockVaultKey extends Mock implements VaultKey {}

class MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

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

/// New password, note, file and Edit (DESIGN.md section 4.11), a private
/// screen: every field takes paste but never offers copy, cut or share;
/// Save stores the item and closes with it; the page closes when My safe
/// locks.
void main() {
  final en = FuzzzyInkLocalizationsEn();
  late MockVaultRepository repository;
  late MockVaultAuthCubit auth;
  late StreamController<VaultAuthState> authStates;
  late MockVaultKey key;
  late Directory temp;
  Object? popped;

  setUpAll(() {
    registerFallbackValue(_passwordItem());
    registerFallbackValue(MockVaultKey());
  });

  setUp(() {
    popped = null;
    FilePicker.platform = _FakeFilePicker();
    temp = Directory.systemTemp.createTempSync('vault_item_editor_');
    sl.safeRegisterSingleton<UserFileStore>(
      UserFileStore(
        supportDirectoryPath: path.join(temp.path, 'support'),
        temporaryDirectoryPath: path.join(temp.path, 'tmp'),
        documentsDirectoryPath: path.join(temp.path, 'documents'),
      ),
    );
    repository = MockVaultRepository();
    when(() => repository.createItem(any(), any())).thenAnswer(
      (invocation) async =>
          VaultSuccess(invocation.positionalArguments.first as VaultItem),
    );
    when(() => repository.updateItem(any(), any())).thenAnswer(
      (invocation) async =>
          VaultSuccess(invocation.positionalArguments.first as VaultItem),
    );
    sl.safeRegisterSingleton<VaultRepository>(repository);
    key = MockVaultKey();
    auth = MockVaultAuthCubit();
    authStates = StreamController<VaultAuthState>();
    whenListen(
      auth,
      authStates.stream,
      initialState: VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
        masterKey: key,
      ),
    );
  });

  tearDown(() async {
    await authStates.close();
    await sl.unregister<UserFileStore>();
    await sl.unregister<VaultRepository>();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> open(
    WidgetTester tester,
    VaultItemEditorPagePayload payload, {
    FuzzzySkin skin = FuzzzySkin.night,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<VaultAuthCubit>.value(
        value: auth,
        child: MaterialApp(
          theme: FuzzzyTheme.build(inkPack, skin),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('host.open'),
                onPressed: () async {
                  popped = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => SensitiveScreen(
                        child: VaultItemEditorPage(payload: payload),
                      ),
                    ),
                  );
                },
                child: const Text('host'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('host.open')));
    await tester.pumpAndSettle();
  }

  for (final skin in redesignSkins) {
    testWidgets(
        'a new password: title, username, password, website, notes '
        '($skin)', (tester) async {
      await open(
        tester,
        const VaultItemEditorPagePayload(
          type: VaultItemType.password,
          groupId: 'work',
        ),
        skin: skin,
      );
      expect(find.text(en.safeNewPasswordTitle), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('field.safe.editor.title')),
        'Bank app',
      );
      await tester.enterText(
        find.byKey(const Key('field.safe.editor.username')),
        'nino@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('field.safe.editor.password')),
        ' Sun-Ink-7741 ',
      );
      await tester.tap(find.byKey(const Key('btn.safe.editor.save')));
      await tester.pumpAndSettle();

      final saved = verify(() => repository.createItem(captureAny(), key))
          .captured
          .single as VaultItem;
      expect(saved.metadata.title, 'Bank app');
      expect(saved.metadata.groupId, 'work');
      expect(saved.passwordContent!.username, 'nino@example.com');
      expect(
        saved.passwordContent!.password,
        ' Sun-Ink-7741 ',
        reason: 'a password is kept exactly as typed',
      );
      expect(popped, same(saved));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every field holding plaintext refuses copy, cut and share',
      (tester) async {
    await open(
      tester,
      VaultItemEditorPagePayload(
        type: VaultItemType.password,
        existingItem: _passwordItem(),
      ),
    );
    expect(find.text(en.safeEdit), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields,
      hasLength(5),
      reason: 'title, username, password, website, notes',
    );
    for (final field in fields) {
      expect(
        field.contextMenuBuilder,
        CopyGuard.plaintextContextMenuBuilder,
        reason: field.controller?.text,
      );
    }
  });

  testWidgets('a long press on the notes offers no copy',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await open(
      tester,
      VaultItemEditorPagePayload(
        type: VaultItemType.password,
        existingItem: _passwordItem(),
      ),
    );
    final note = find.text('pin is under the plant');
    await tester.longPressAt(tester.getTopLeft(note) + const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Select all'), findsOneWidget, reason: 'menu is open');
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('a new file asks for the file before saving', (tester) async {
    await open(
      tester,
      const VaultItemEditorPagePayload(type: VaultItemType.file),
    );
    expect(find.text(en.safeNewFileTitle), findsOneWidget);
    expect(find.text(en.safeChooseFile), findsWidgets);

    await tester.tap(find.byKey(const Key('btn.safe.editor.save')));
    await tester.pump();
    expect(find.text(en.safeChooseFileFirst), findsOneWidget);
    verifyNever(() => repository.createItem(any(), any()));
  });

  testWidgets('an edit updates the same item, one version up', (tester) async {
    await open(
      tester,
      VaultItemEditorPagePayload(
        type: VaultItemType.password,
        existingItem: _passwordItem(),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('field.safe.editor.title')),
      'Bank, new',
    );
    await tester.tap(find.byKey(const Key('btn.safe.editor.save')));
    await tester.pumpAndSettle();

    final saved = verify(() => repository.updateItem(captureAny(), key))
        .captured
        .single as VaultItem;
    expect(saved.metadata.id, 'item-1');
    expect(saved.metadata.title, 'Bank, new');
    expect(saved.metadata.contentVersion, 2);
    expect(saved.passwordContent!.notes, 'pin is under the plant');
    verifyNever(() => repository.createItem(any(), any()));
  });

  testWidgets('My safe locks: the editor closes', (tester) async {
    await open(
      tester,
      const VaultItemEditorPagePayload(type: VaultItemType.note),
    );
    expect(find.text(en.safeNewNoteTitle), findsOneWidget);
    authStates.add(
      const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.locked,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VaultItemEditorPage), findsNothing);
  });
}
