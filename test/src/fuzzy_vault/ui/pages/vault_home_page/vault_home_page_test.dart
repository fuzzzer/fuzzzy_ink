import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/redesign_harness.dart';

class MockVaultRepository extends Mock implements VaultRepository {}

class MockVaultKey extends Mock implements VaultKey {}

class MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

VaultItemMetadata _meta(
  String id,
  String title,
  VaultItemType type, {
  String groupId = VaultGroupData.generalGroupId,
}) =>
    VaultItemMetadata(
      id: id,
      title: title,
      type: type,
      groupId: groupId,
      tags: const [],
      isFavorite: false,
      hasCustomPassword: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      contentVersion: 1,
    );

VaultGroupData _group(String id, String name) => VaultGroupData(
      id: id,
      name: name,
      emoji: '',
      colorIndex: 0,
      sortOrder: 0,
      hasCustomPassword: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// My safe, open (DESIGN.md section 4.11): search, the four switches, group
/// chips with New group, rows that never show a secret, the empty and
/// nothing-found states, the auto-lock line, Add, and Move by long press.
void main() {
  final en = FuzzzyInkLocalizationsEn();
  late MockVaultRepository repository;
  late MockVaultAuthCubit auth;
  late List<VaultItemMetadata> items;
  late List<VaultGroupData> groups;

  setUpAll(() {
    registerFallbackValue(_group('x', 'x'));
    registerFallbackValue(MockVaultKey());
  });

  setUp(() async {
    items = [
      _meta('p1', 'Bank app', VaultItemType.password, groupId: 'home'),
      _meta('n1', 'Passport number', VaultItemType.note, groupId: 'home'),
      _meta('f1', 'Home insurance', VaultItemType.file),
      _meta('p2', 'Work email', VaultItemType.password, groupId: 'work'),
    ];
    groups = [
      _group(VaultGroupData.generalGroupId, VaultGroupData.generalGroupName),
      _group('home', 'Home'),
      _group('work', 'Work'),
    ];
    repository = MockVaultRepository();
    when(() => repository.vaultDataUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.getAllItems())
        .thenAnswer((_) async => VaultSuccess(items));
    when(() => repository.getAllGroups())
        .thenAnswer((_) async => VaultSuccess(groups));
    when(() => repository.searchItems(any()))
        .thenAnswer((_) async => const VaultSuccess([]));
    when(() => repository.createGroup(any())).thenAnswer(
      (invocation) async =>
          VaultSuccess(invocation.positionalArguments.first as VaultGroupData),
    );
    when(() => repository.moveItemToGroup(any(), any())).thenAnswer(
      (_) async => VaultSuccess(items.first),
    );
    auth = MockVaultAuthCubit();
    whenListen(
      auth,
      const Stream<VaultAuthState>.empty(),
      initialState: const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
      ),
    );
    SharedPreferences.setMockInitialValues({});
    sl
      ..safeRegisterSingleton<PreferencesService>(
        PreferencesService(await SharedPreferences.getInstance()),
      )
      ..safeRegisterSingleton<VaultRepository>(repository);
  });

  tearDown(() async {
    await sl.unregister<PreferencesService>();
    await sl.unregister<VaultRepository>();
  });

  Future<void> pump(
    WidgetTester tester, {
    FuzzzySkin skin = FuzzzySkin.night,
    Locale locale = const Locale('en'),
    Size? surface,
    double textScale = 1,
  }) async {
    await pumpRedesign(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<VaultAuthCubit>.value(value: auth),
          BlocProvider(
            create: (_) => VaultItemsCubit(vaultRepository: repository),
          ),
          BlocProvider(
            create: (_) => VaultGroupsCubit(vaultRepository: repository),
          ),
          BlocProvider(
            create: (_) => VaultSearchCubit(vaultRepository: repository),
          ),
        ],
        child: const VaultHomePage(),
      ),
      skin: skin,
      locale: locale,
      surface: surface,
      textScale: textScale,
      private: true,
    );
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(Key('safe.item.$id'));

  for (final skin in redesignSkins) {
    testWidgets('the items, their type and group, never a secret ($skin)',
        (tester) async {
      await pump(tester, skin: skin);

      expect(row('p1'), findsOneWidget);
      expect(find.text('Bank app'), findsOneWidget);
      expect(find.text('${en.vaultPasswordLabel} · Home'), findsOneWidget);
      expect(find.text(en.vaultFileLabel), findsOneWidget, reason: 'no group');
      expect(find.text(en.safeAutoLockTip(5)), findsOneWidget);
      expect(find.byKey(const Key('btn.safe.add')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'with the safe open, rows show the username or file name, sealed '
      'apart from the item; the type where there is none '
      '(final regression 2026-10-26)', (tester) async {
    final key = MockVaultKey();
    whenListen(
      auth,
      const Stream<VaultAuthState>.empty(),
      initialState: VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
        masterKey: key,
      ),
    );
    when(() => repository.readLabels(any(), key)).thenAnswer(
      (_) async => {'p1': 'tamar@mail.ge', 'f1': 'policy.pdf'},
    );
    await pump(tester);

    expect(find.text('tamar@mail.ge · Home'), findsOneWidget);
    expect(find.text('policy.pdf'), findsOneWidget);
    expect(find.text('${en.vaultPasswordLabel} · Work'), findsOneWidget);
    verifyNever(() => repository.getItem(any(), any()));
  });

  testWidgets('All · Passwords · Notes · Files, remembered', (tester) async {
    await pump(tester);

    await tester.tap(find.text(en.vaultPasswords));
    await tester.pumpAndSettle();
    expect(row('p1'), findsOneWidget);
    expect(row('p2'), findsOneWidget);
    expect(row('n1'), findsNothing);
    expect(row('f1'), findsNothing);
    expect(sl.get<PreferencesService>().vaultLastSelectedTabIndex, 1);

    await tester.tap(find.text(en.vaultFiles));
    await tester.pumpAndSettle();
    expect(row('f1'), findsOneWidget);
    expect(row('p1'), findsNothing);
  });

  testWidgets('group chips filter; All groups shows everything again',
      (tester) async {
    await pump(tester);
    expect(
      find.byKey(const Key('chip.safe.group.${VaultGroupData.generalGroupId}')),
      findsNothing,
      reason: 'the general group is "No group", not a chip',
    );

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(row('p2'), findsOneWidget);
    expect(row('p1'), findsNothing);

    await tester.tap(find.text(en.safeAllGroups));
    await tester.pumpAndSettle();
    expect(row('p1'), findsOneWidget);
    expect(row('p2'), findsOneWidget);
  });

  testWidgets('empty: "Nothing here yet. Tap Add."', (tester) async {
    items = [];
    await pump(tester);
    expect(find.text(en.safeEmptyTitle), findsOneWidget);
    expect(find.text(en.safeEmptyLine), findsOneWidget);
    expect(find.text(en.safeAutoLockTip(5)), findsOneWidget);
  });

  testWidgets('a search that finds nothing says so', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('field.safe.search')), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text(en.safeNothingFound), findsOneWidget);
    expect(find.text(en.safeTryAnotherWord), findsOneWidget);
    verify(() => repository.searchItems('zzz')).called(1);
  });

  testWidgets('Add offers Password, Note and File', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('btn.safe.add')));
    await tester.pumpAndSettle();
    expect(find.text(en.safeAddTitle), findsOneWidget);
    for (final type in VaultItemType.values) {
      expect(find.byKey(Key('safe.add.${type.name}')), findsOneWidget);
    }
  });

  testWidgets('New group: a name, then the new chip is chosen', (tester) async {
    await pump(tester);
    await tester.tap(find.text(en.safeNewGroup));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('field.safe.newGroup.name')),
      '  Family ',
    );
    await tester.pump();
    groups = [...groups, _group('family', 'Family')];
    await tester.tap(find.byKey(const Key('btn.safe.newGroup.add')));
    await tester.pumpAndSettle();

    final created = verify(() => repository.createGroup(captureAny()))
        .captured
        .single as VaultGroupData;
    expect(created.name, 'Family');
  });

  testWidgets('a long press moves an item to a group', (tester) async {
    await pump(tester);
    await tester.longPress(row('f1'));
    await tester.pumpAndSettle();
    expect(find.text(en.safeMoveToGroup), findsOneWidget);

    await tester.tap(find.byKey(const Key('safe.move.work')));
    await tester.pumpAndSettle();
    verify(() => repository.moveItemToGroup('f1', 'work')).called(1);
    expect(find.text(en.safeMovedTo('Work')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Georgian, small phone, large text: nothing overflows',
      (tester) async {
    await pump(
      tester,
      locale: const Locale('ka'),
      surface: const Size(360, 720),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
