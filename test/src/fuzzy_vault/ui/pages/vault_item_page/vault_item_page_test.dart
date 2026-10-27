import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/redesign_harness.dart';

class MockVaultRepository extends Mock implements VaultRepository {}

class MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

/// Records what the copy guard puts on the clipboard; the clear always
/// finds the app's own copy.
class _RecordingClipboard extends SecureClipboard {
  final written = <({String text, bool sensitive})>[];
  int clears = 0;

  @override
  Future<void> write(
    String text, {
    required bool sensitive,
    required Duration clearAfter,
  }) async =>
      written.add((text: text, sensitive: sensitive));

  @override
  Future<ClipboardClearResult> clearIfStillOurs() async {
    clears++;
    return ClipboardClearResult.cleared;
  }
}

VaultItemMetadata _meta(VaultItemType type, String title) => VaultItemMetadata(
      id: 'item-1',
      title: title,
      type: type,
      groupId: VaultGroupData.generalGroupId,
      tags: const [],
      isFavorite: false,
      hasCustomPassword: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      contentVersion: 1,
    );

VaultItem _password() => VaultItem(
      metadata: _meta(VaultItemType.password, 'Bank app'),
      passwordContent: const VaultPasswordContent(
        username: 'nino@example.com',
        password: 'hunter2',
        url: 'bank.example',
        notes: 'pin is under the plant',
      ),
    );

VaultItem _note() => VaultItem(
      metadata: _meta(VaultItemType.note, 'Passport number'),
      noteContent: const VaultNoteContent(
        delta: [],
        plainText: '13AB45678 · valid until 2031',
      ),
    );

VaultItem _file(String name, List<int> bytes) => VaultItem(
      metadata: _meta(VaultItemType.file, name),
      fileContent: VaultFileContent(fileName: name, fileBytes: bytes),
    );

/// A My safe item, a private screen (DESIGN.md section 4.11): the password
/// hidden until shown, its copy button with the truthful countdown and
/// "Cleared.", the Settings switch, a note that cannot be selected, a file
/// opened from memory, Move and Delete, and closing when My safe locks.
void main() {
  final en = FuzzzyInkLocalizationsEn();
  late MockVaultRepository repository;
  late MockVaultAuthCubit auth;
  late StreamController<VaultAuthState> authStates;
  late _RecordingClipboard clipboard;
  late Directory temp;
  late UserFileStore store;

  const unlocked = VaultAuthState(
    status: StateStatus.success,
    authState: VaultAuthEnum.unlocked,
  );

  setUp(() async {
    repository = MockVaultRepository();
    when(() => repository.getAllGroups()).thenAnswer(
      (_) async => VaultSuccess([
        VaultGroupData(
          id: 'work',
          name: 'Work',
          emoji: '',
          colorIndex: 0,
          sortOrder: 0,
          hasCustomPassword: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]),
    );
    when(() => repository.deleteItem(any()))
        .thenAnswer((_) async => const VaultSuccess(null));
    when(() => repository.moveItemToGroup(any(), any()))
        .thenAnswer((_) async => VaultSuccess(_meta(VaultItemType.note, 'x')));
    auth = MockVaultAuthCubit();
    authStates = StreamController<VaultAuthState>();
    whenListen(auth, authStates.stream, initialState: unlocked);

    clipboard = _RecordingClipboard();
    CopyGuard.clipboardGuard = ClipboardGuard(clipboard: clipboard);

    temp = Directory.systemTemp.createTempSync('vault_item_page_');
    store = UserFileStore(
      supportDirectoryPath: path.join(temp.path, 'support'),
      temporaryDirectoryPath: path.join(temp.path, 'tmp'),
      documentsDirectoryPath: path.join(temp.path, 'documents'),
    );
    SharedPreferences.setMockInitialValues({});
    sl
      ..safeRegisterSingleton<PreferencesService>(
        PreferencesService(await SharedPreferences.getInstance()),
      )
      ..safeRegisterSingleton<VaultRepository>(repository)
      ..safeRegisterSingleton<UserFileStore>(store);
  });

  tearDown(() async {
    await authStates.close();
    CopyGuard.clipboardGuard.dispose();
    CopyGuard.clipboardGuard = ClipboardGuard();
    await sl.unregister<PreferencesService>();
    await sl.unregister<VaultRepository>();
    await sl.unregister<UserFileStore>();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// The item page pushed over a host page, the way the app opens it.
  Future<void> open(
    WidgetTester tester,
    VaultItem item, {
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SensitiveScreen(child: VaultItemPage(item: item)),
                  ),
                ),
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

  group('password', () {
    for (final skin in redesignSkins) {
      testWidgets('hidden until shown; username, website, notes ($skin)',
          (tester) async {
        await open(tester, _password(), skin: skin);

        expect(find.text('nino@example.com'), findsOneWidget);
        expect(find.text('hunter2'), findsNothing);
        expect(find.text('•' * 12), findsOneWidget);
        expect(find.text('bank.example'), findsOneWidget);
        expect(find.text('pin is under the plant'), findsOneWidget);
        expect(find.byType(SelectableText), findsNothing);
        expect(find.byType(EditableText), findsNothing);

        await tester.tap(find.byKey(const Key('iconbtn.safe.item.show')));
        await tester.pump();
        expect(find.text('hunter2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'copy: a check in place, "Copied · clears in N s" counting down, then '
        '"Cleared." when the guard really cleared it', (tester) async {
      final haptics = recordHaptics(tester);
      await open(tester, _password());
      expect(find.text(en.safeCopyRule(30)), findsOneWidget);

      await tester.tap(find.byKey(const Key('iconbtn.safe.item.copy')));
      await tester.pump();
      expect(clipboard.written.single, (text: 'hunter2', sensitive: true));
      expect(find.text(en.safeCopiedClearsIn(30)), findsOneWidget);
      expect(find.byType(CheckDraw), findsOneWidget);
      expect(haptics, contains('HapticFeedbackType.lightImpact'));

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(en.safeCopiedClearsIn(29)), findsOneWidget);

      await tester.pump(const Duration(seconds: 28));
      expect(find.text(en.safeCopiedClearsIn(1)), findsOneWidget);
      expect(clipboard.clears, 0);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(clipboard.clears, 1);
      expect(
        find.text('${en.safeCleared} ${en.safeCopyRule(30)}'),
        findsOneWidget,
      );
      expect(find.byType(CheckDraw), findsNothing);
    });

    testWidgets('the Settings switch off: no copy button, the line says so',
        (tester) async {
      await sl.get<PreferencesService>().setVaultPasswordCopy(false);
      await open(tester, _password());
      expect(find.byKey(const Key('iconbtn.safe.item.copy')), findsNothing);
      expect(find.text(en.safeCopyOff), findsOneWidget);
    });
  });

  testWidgets('a note is shown but cannot be selected or copied',
      (tester) async {
    await open(tester, _note());
    expect(find.text('13AB45678 · valid until 2031'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsNothing);
    expect(find.text(en.tagNoCopy.toUpperCase()), findsOneWidget);
  });

  group('file', () {
    testWidgets('Open shows a text file inside the app; nothing is written',
        (tester) async {
      await open(tester, _file('note.txt', utf8.encode('the secret')));
      expect(find.textContaining(en.fileCardKeptInSafe), findsOneWidget);
      expect(find.text(en.safeSaveTip), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn.safe.item.open')));
      await tester.pumpAndSettle();
      expect(find.byType(PlainFileViewerPage), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(PlainFileViewerPage),
          matching: find.byType(SensitiveScreen),
        ),
        findsOneWidget,
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('the secret'), findsOneWidget);
      expect(Directory(store.handoffRootPath).existsSync(), isFalse);
    });

    testWidgets('a program is not shown or run: the viewer offers Save only',
        (tester) async {
      await open(tester, _file('setup.exe', [0x4D, 0x5A]));
      await tester.tap(find.byKey(const Key('btn.safe.item.open')));
      await tester.pumpAndSettle();
      expect(find.text(en.fileNoPreview), findsOneWidget);
      expect(Directory(store.handoffRootPath).existsSync(), isFalse);
    });
  });

  testWidgets('More → Move to a group moves it and says where', (tester) async {
    await open(tester, _note());
    expect(find.text(en.safeNoGroup), findsOneWidget);

    await tester.tap(find.byKey(const Key('iconbtn.safe.item.more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safe.menu.move')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safe.move.work')));
    await tester.pumpAndSettle();

    verify(() => repository.moveItemToGroup('item-1', 'work')).called(1);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text(en.safeMovedTo('Work')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('More → Delete asks first, then deletes and closes',
      (tester) async {
    await open(tester, _note());
    await tester.tap(find.byKey(const Key('iconbtn.safe.item.more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safe.menu.delete')));
    await tester.pumpAndSettle();
    expect(find.text(en.safeDeleteTitle('Passport number')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn.safe.delete.cancel')));
    await tester.pumpAndSettle();
    verifyNever(() => repository.deleteItem(any()));
    expect(find.byType(VaultItemPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('iconbtn.safe.item.more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safe.menu.delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn.safe.delete.confirm')));
    await tester.pumpAndSettle();

    verify(() => repository.deleteItem('item-1')).called(1);
    expect(find.byType(VaultItemPage), findsNothing);
    expect(find.text(en.safeDeleted), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('My safe locks: the item closes', (tester) async {
    await open(tester, _password());
    authStates.add(
      const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.locked,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VaultItemPage), findsNothing);
    expect(find.text('nino@example.com'), findsNothing);
  });
}
