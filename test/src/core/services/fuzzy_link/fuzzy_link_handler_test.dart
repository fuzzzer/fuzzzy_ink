import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFuzzyLinkService extends Mock implements FuzzyLinkService {}

class MockChatGeneralDataListRepository extends Mock
    implements ChatGeneralDataListRepository {}

class MockFuzzyAuthStore extends Mock implements FuzzyAuthStore {}

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

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
          .copyWith(status: AuthStateStatus.noAuthRequired),
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
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        localizationsDelegates: FuzzzySealLocalizations.localizationsDelegates,
        supportedLocales: FuzzzySealLocalizations.supportedLocales,
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
      FuzzyLinkGenerator.generateInvitationLink(_invitation),
    );

    expect(find.text("You can't accept your own invitation."), findsOneWidget);
    expect(find.text('chat list'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    await settleMessage(tester);
    handler.dispose();
  });

  testWidgets(
      'an acceptance link for a connected chat shows alreadyConnected, '
      'stays on the list and throws nothing', (tester) async {
    when(() => chatRepository.getChatById(_chatId))
        .thenAnswer((_) async => _chat(ChatSetupStatus.connected));
    final handler = await pumpApp(tester);

    await receive(
      tester,
      FuzzyLinkGenerator.generateAcceptanceLink(_acceptance),
    );

    expect(find.text('Already connected!'), findsOneWidget);
    expect(find.text('chat list'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
    await settleMessage(tester);
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
      FuzzyLinkGenerator.generateInvitationLink(_invitation),
    );

    expect(find.byType(SnackBar), findsNothing);
    verify(() => chatRepository.getChatById(_chatId)).called(1);
    expect(tester.takeException(), isNull);
    handler.dispose();
  });

  testWidgets('an unparsable link shows invalidLink', (tester) async {
    final handler = await pumpApp(tester);

    await receive(tester, 'fuzzylink://invite/not-valid-base64!!!');

    expect(find.byType(SnackBar), findsOneWidget);
    verifyNever(() => chatRepository.getChatById(any()));
    await settleMessage(tester);
    handler.dispose();
  });
}
