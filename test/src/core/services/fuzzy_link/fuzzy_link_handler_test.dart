import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFuzzyLinkService extends Mock implements FuzzyLinkService {}

class MockChatGeneralDataListRepository extends Mock
    implements ChatGeneralDataListRepository {}

class MockFuzzyAuthStore extends Mock implements FuzzyAuthStore {}

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockIncomingFiles extends Mock implements IncomingFiles {}

class MockUserFileStore extends Mock implements UserFileStore {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _invitation = 'Fuzz/RlVaWgEBJDZmMWU5YjJjLTNkNGEtNGY1Yi04YzZkLTdlOGY5YTBi';
const _acceptance = 'Fuzz/RlVaWgECJDZmMWU5YjJjLTNkNGEtNGY1Yi04YzZkLTdlOGY5YTBi';

ChatGeneralData _chat(ChatSetupStatus status) => ChatGeneralData(
      chatId: _chatId,
      chatName: 'Alice',
      setupStatus: status,
      didAcceptInvitation: false,
    );

/// [FuzzyLinkHandler]'s messages go through the app's `ScaffoldMessenger`
/// (T-0328); the app shell is reduced to a `MaterialApp` on the real
/// `navigatorKey` / `scaffoldMessengerKey` with a `Scaffold` home.
/// `AppRouter.routerInstance` is null here, so the navigate branch is a no-op
/// — that the accept page opens prefilled is proven by the live QA pass.
void main() {
  late MockFuzzyLinkService linkService;
  late MockChatGeneralDataListRepository chatRepository;
  late MockFuzzyAuthStore authStore;
  late MockCryptoCoreService cryptoCoreService;
  late StreamController<Uri> links;

  setUp(() {
    linkService = MockFuzzyLinkService();
    chatRepository = MockChatGeneralDataListRepository();
    authStore = MockFuzzyAuthStore();
    cryptoCoreService = MockCryptoCoreService();
    links = StreamController<Uri>();

    when(() => linkService.getInitialLink()).thenAnswer((_) async => null);
    when(() => linkService.onLinkReceived).thenAnswer((_) => links.stream);
    when(() => authStore.state).thenReturn(
      const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.authenticated),
    );
    when(() => cryptoCoreService.peekChatId(_invitation))
        .thenReturn(const CryptoCoreSuccess(_chatId));
    when(() => cryptoCoreService.peekChatId(_acceptance))
        .thenReturn(const CryptoCoreSuccess(_chatId));
  });

  tearDown(() => links.close());

  Future<FuzzyLinkHandler> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: const Scaffold(body: Text('chat list')),
      ),
    );
    final handler = FuzzyLinkHandler(
      linkService: linkService,
      chatRepository: chatRepository,
      authStore: authStore,
      cryptoCoreService: cryptoCoreService,
    );
    await handler.initialize();
    return handler;
  }

  Future<void> receive(WidgetTester tester, String link) async {
    links.add(Uri.parse(link));
    await tester.pump();
    await tester.pump();
  }

  /// Lets the snack bar's own timer expire so the test ends with no pending
  /// timers.
  Future<void> settleMessage(WidgetTester tester) =>
      tester.pumpAndSettle(const Duration(seconds: 5));

  testWidgets(
      'an invitation link for a chat this device holds shows '
      'cantAcceptOwnInvitation and stays on the list', (tester) async {
    when(() => chatRepository.getChatById(_chatId))
        .thenAnswer((_) async => _chat(ChatSetupStatus.invited));
    final handler = await pumpApp(tester);

    await receive(
      tester,
      FuzzyLinkGenerator.generateInvitationLink(_invitation)!,
    );

    expect(find.text("You can't accept your own invitation."), findsOneWidget);
    expect(find.text('chat list'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    await settleMessage(tester);
    handler.dispose();
  });

  testWidgets(
      'the acceptance that paired a connected chat, arriving again, shows '
      'alreadyConnected, stays on the list and throws nothing', (tester) async {
    when(() => chatRepository.getChatById(_chatId))
        .thenAnswer((_) async => _chat(ChatSetupStatus.connected));
    when(() => chatRepository.isPairedAcceptance(_chatId, _acceptance))
        .thenAnswer((_) async => true);
    final handler = await pumpApp(tester);

    await receive(
      tester,
      FuzzyLinkGenerator.generateAcceptanceLink(_acceptance)!,
    );

    expect(find.text('Already connected!'), findsOneWidget);
    expect(find.text('chat list'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
    await settleMessage(tester);
    handler.dispose();
  });

  Future<FuzzyLinkHandler> pumpRouted(WidgetTester tester) async {
    final router = GoRouter(
      navigatorKey: navigatorKey,
      routes: [
        GoRoute(
          path: AppRouter.home,
          builder: (_, __) => const Scaffold(body: Text('chat list')),
        ),
        GoRoute(
          path: AppRouter.personAnsweredTwice,
          builder: (_, state) => Scaffold(
            body: Text(
              'answered twice: ${(state.extra! as ChatGeneralData).chatName}',
            ),
          ),
        ),
      ],
    );
    AppRouter.debugRouterInstance = router;
    addTearDown(() {
      AppRouter.debugRouterInstance = null;
      router.dispose();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        scaffoldMessengerKey: scaffoldMessengerKey,
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    final handler = FuzzyLinkHandler(
      linkService: linkService,
      chatRepository: chatRepository,
      authStore: authStore,
      cryptoCoreService: cryptoCoreService,
    );
    await handler.initialize();
    return handler;
  }

  testWidgets(
      'a different acceptance that really answers the invite opens "Someone '
      'else may have answered", never says "connected"', (tester) async {
    when(() => chatRepository.getChatById(_chatId))
        .thenAnswer((_) async => _chat(ChatSetupStatus.connected));
    when(() => chatRepository.isPairedAcceptance(_chatId, _acceptance))
        .thenAnswer((_) async => false);
    when(
      () => cryptoCoreService.checkAcceptance(
        chatId: _chatId,
        acceptance: _acceptance,
      ),
    ).thenAnswer((_) async => const CryptoCoreSuccess(null));
    final handler = await pumpRouted(tester);

    await receive(
      tester,
      FuzzyLinkGenerator.generateAcceptanceLink(_acceptance)!,
    );
    await tester.pumpAndSettle();

    expect(find.text('answered twice: Alice'), findsOneWidget);
    expect(find.text('Already connected!'), findsNothing);
    expect(tester.takeException(), isNull);
    handler.dispose();
  });

  testWidgets(
      'a forged or junk reply for a connected chat raises no alarm: it is '
      'just not a valid reply (security review 2026-10-26)', (tester) async {
    when(() => chatRepository.getChatById(_chatId))
        .thenAnswer((_) async => _chat(ChatSetupStatus.connected));
    when(() => chatRepository.isPairedAcceptance(_chatId, _acceptance))
        .thenAnswer((_) async => false);
    when(
      () => cryptoCoreService.checkAcceptance(
        chatId: _chatId,
        acceptance: _acceptance,
      ),
    ).thenAnswer(
      (_) async => const CryptoCoreFailure(CryptoCoreFailureType.wrongChat),
    );
    final handler = await pumpRouted(tester);

    await receive(
      tester,
      FuzzyLinkGenerator.generateAcceptanceLink(_acceptance)!,
    );
    await tester.pump();

    expect(find.text('answered twice: Alice'), findsNothing);
    expect(find.text('chat list'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    await settleMessage(tester);
    handler.dispose();
  });

  testWidgets(
      "a link waits while My safe's editor holds links, then opens "
      '(security review 2026-10-26)', (tester) async {
    when(() => chatRepository.getChatById(_chatId))
        .thenAnswer((_) async => _chat(ChatSetupStatus.connected));
    when(() => chatRepository.isPairedAcceptance(_chatId, _acceptance))
        .thenAnswer((_) async => true);
    final handler = await pumpApp(tester);
    final release = handler.holdLinks();

    await receive(
      tester,
      FuzzyLinkGenerator.generateAcceptanceLink(_acceptance)!,
    );
    expect(handler.hasPendingPayload, isTrue);
    expect(handler.pendingLink.value, isTrue);
    verifyNever(() => chatRepository.getChatById(any()));
    await settleMessage(tester);

    release();
    await tester.pump();
    await tester.pump();
    expect(handler.hasPendingPayload, isFalse);
    verify(() => chatRepository.getChatById(_chatId)).called(1);
    await settleMessage(tester);
    handler.dispose();
  });

  testWidgets(
      'a link that arrives while the app is locked waits for the unlock',
      (tester) async {
    when(() => authStore.state).thenReturn(
      const FuzzyAuthState.initial().copyWith(status: AuthStateStatus.locked),
    );
    when(() => chatRepository.getChatById(_chatId))
        .thenAnswer((_) async => null);
    final handler = await pumpApp(tester);

    await receive(
      tester,
      FuzzyLinkGenerator.generateInvitationLink(_invitation)!,
    );

    expect(handler.hasPendingPayload, isTrue);
    verifyNever(() => chatRepository.getChatById(any()));

    handler.processPendingPayload();
    await tester.pump();

    expect(handler.hasPendingPayload, isFalse);
    verify(() => chatRepository.getChatById(_chatId)).called(1);
    handler.dispose();
  });

  testWidgets(
      'a foreign invitation link shows no message and goes on to the '
      'accept page', (tester) async {
    when(() => chatRepository.getChatById(_chatId))
        .thenAnswer((_) async => null);
    final handler = await pumpApp(tester);

    await receive(
      tester,
      FuzzyLinkGenerator.generateInvitationLink(_invitation)!,
    );

    expect(find.byType(SnackBar), findsNothing);
    verify(() => chatRepository.getChatById(_chatId)).called(1);
    expect(tester.takeException(), isNull);
    handler.dispose();
  });

  testWidgets(
      'a message link goes to Open, which checks the person: no message '
      'here and no chat read', (tester) async {
    final handler = await pumpApp(tester);

    await receive(
      tester,
      FuzzyLinkGenerator.generateFuzzLink('Fuzz/AwEC')!,
    );

    expect(find.byType(SnackBar), findsNothing);
    verifyNever(() => chatRepository.getChatById(any()));
    expect(tester.takeException(), isNull);
    handler.dispose();
  });

  testWidgets('an unparsable link shows invalidLink', (tester) async {
    final handler = await pumpApp(tester);

    await receive(tester, 'https://ink.fuzzzycore.com/invite#not-valid!!!');

    expect(find.byType(SnackBar), findsOneWidget);
    verifyNever(() => chatRepository.getChatById(any()));
    await settleMessage(tester);
    handler.dispose();
  });

  group('a .fuzz file opened from another app', () {
    const fileUri = 'content://com.android.providers.downloads/document/7';
    late String copy;
    late Directory temp;
    late MockUserFileStore fileStore;
    late MockIncomingFiles incomingFiles;
    late StreamController<Uri> desktopFiles;
    late List<(String, Object?)> went;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('incoming_test');
      copy = '${temp.path}/note.fuzz';
      File(copy).writeAsStringSync('Fuzz/sealed');
      fileStore = MockUserFileStore();
      when(() => fileStore.wipe(any())).thenAnswer((_) async {});
      incomingFiles = MockIncomingFiles();
      when(() => incomingFiles.userFileStore).thenReturn(fileStore);
      desktopFiles = StreamController<Uri>();
      went = [];
      registerFallbackValue(Uri());
      when(() => incomingFiles.opened).thenAnswer((_) => desktopFiles.stream);
      when(() => incomingFiles.start()).thenAnswer((_) async {});
      when(() => incomingFiles.take(Uri.parse(fileUri)))
          .thenAnswer((_) async => copy);
    });

    tearDown(() {
      desktopFiles.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    Future<FuzzyLinkHandler> pumpWithFiles(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: const Scaffold(body: Text('chat list')),
        ),
      );
      final handler = FuzzyLinkHandler(
        linkService: linkService,
        chatRepository: chatRepository,
        authStore: authStore,
        cryptoCoreService: cryptoCoreService,
        incomingFiles: incomingFiles,
        navigate: (path, extra) => went.add((path, extra)),
      );
      await handler.initialize();
      return handler;
    }

    /// Open gets it as an arrived file, never as a chosen one: a message,
    /// a person's file or a reply then waits for the person's Open or
    /// Connect, so no one-time key is spent on arrival (security review
    /// 2026-10-26).
    void expectOpenedInOpen() {
      expect(went, hasLength(1));
      final (path, extra) = went.single;
      expect(path, AppRouter.open);
      final request = (extra! as OpenPagePayload).request;
      expect(request, isA<OpenArrivedFile>());
      expect(request, isNot(isA<OpenChosenFile>()));
      expect((request! as OpenArrivedFile).filePath, copy);
    }

    testWidgets('is copied once and goes to Open, never as a link',
        (tester) async {
      final handler = await pumpWithFiles(tester);
      await receive(tester, fileUri);

      verify(() => incomingFiles.take(Uri.parse(fileUri))).called(1);
      expectOpenedInOpen();
      expect(find.text('This link is invalid or corrupted.'), findsNothing);
      handler.dispose();
    });

    testWidgets('handed over by the desktop (macOS) opens the same way',
        (tester) async {
      final handler = await pumpWithFiles(tester);
      desktopFiles.add(Uri.parse(fileUri));
      await tester.pump();
      await tester.pump();

      expectOpenedInOpen();
      verify(() => incomingFiles.start()).called(1);
      handler.dispose();
    });

    testWidgets('while the app is locked, waits for the unlock',
        (tester) async {
      when(() => authStore.state).thenReturn(
        const FuzzyAuthState.initial().copyWith(status: AuthStateStatus.locked),
      );
      final handler = await pumpWithFiles(tester);
      await receive(tester, fileUri);

      expect(went, isEmpty);
      expect(handler.hasPendingPayload, isTrue);
      expect(handler.pendingLink.value, isTrue);

      handler.processPendingPayload();
      expectOpenedInOpen();
      expect(handler.hasPendingPayload, isFalse);
      expect(handler.pendingLink.value, isFalse);
      handler.dispose();
    });

    testWidgets(
        'still waiting on Open when the app locks, it waits for the unlock '
        '(lock on return, seen live 2026-10-26)', (tester) async {
      final handler = await pumpWithFiles(tester);
      await receive(tester, fileUri);
      expectOpenedInOpen();

      handler.keepWaitingFileAtLock();
      verify(() => fileStore.keepForUnlock(copy)).called(1);
      expect(handler.hasPendingPayload, isTrue);
      expect(handler.pendingLink.value, isTrue);

      went.clear();
      handler.processPendingPayload();
      expectOpenedInOpen();
      verify(() => fileStore.release(copy)).called(greaterThanOrEqualTo(1));
      handler.dispose();
    });

    testWidgets('used or left on Open before the lock, it is not brought back',
        (tester) async {
      final handler = await pumpWithFiles(tester);
      await receive(tester, fileUri);
      File(copy).deleteSync();

      handler.keepWaitingFileAtLock();
      verifyNever(() => fileStore.keepForUnlock(any()));
      expect(handler.hasPendingPayload, isFalse);
      handler.dispose();
    });

    testWidgets('that cannot be read says so and opens nothing',
        (tester) async {
      when(() => incomingFiles.take(Uri.parse(fileUri)))
          .thenAnswer((_) async => null);
      final handler = await pumpWithFiles(tester);
      await receive(tester, fileUri);

      expect(went, isEmpty);
      expect(
        find.text("Couldn't read that file. Open it again from where it is."),
        findsOneWidget,
      );
      await settleMessage(tester);
      handler.dispose();
    });
  });
}
