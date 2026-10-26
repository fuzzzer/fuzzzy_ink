import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockChatGeneralDataListCubit extends MockCubit<ChatGeneralDataListState>
    implements ChatGeneralDataListCubit {}

class MockConnectedChatCubit extends MockCubit<ConnectedChatState>
    implements ConnectedChatCubit {}

class MockSafetyNumberCubit extends MockCubit<SafetyNumberState>
    implements SafetyNumberCubit {}

class MockChatFileCubit extends MockCubit<ChatFileState>
    implements ChatFileCubit {}

class MockChatCreationCubit extends MockCubit<ChatCreationState>
    implements ChatCreationCubit {}

class MockInvitationReaderCubit extends MockCubit<InvitationReaderState>
    implements InvitationReaderCubit {}

class MockHandshakeCubit extends MockCubit<HandshakeState>
    implements HandshakeCubit {}

class MockInvitationAcceptanceCubit extends MockCubit<InvitationAcceptanceState>
    implements InvitationAcceptanceCubit {}

class MockAcceptanceReaderCubit extends MockCubit<AcceptanceReaderState>
    implements AcceptanceReaderCubit {}

const peopleChatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

ChatGeneralData personChat({
  String name = 'Nino',
  ChatSetupStatus status = ChatSetupStatus.connected,
  bool didAcceptInvitation = false,
}) =>
    ChatGeneralData(
      chatId: peopleChatId,
      chatName: name,
      setupStatus: status,
      didAcceptInvitation: didAcceptInvitation,
    );

/// Where the flows went: every route the people screens use is a stub that
/// names itself ("to /person/checked Nino", "to /person?chat=…").
String stubText(GoRouterState state) {
  final extra = switch (state.extra) {
    final ChatGeneralData chat => ' ${chat.chatName}',
    final ChatInvitationPagePayload payload =>
      ' ${payload.chatName}${payload.prefillAcceptanceContent == null ? '' : ' reply ${payload.prefillAcceptanceContent}'}${payload.justMade ? ' new' : ''}',
    final AcceptanceExportPagePayload payload =>
      ' ${payload.chatGeneralData.chatName}',
    final HistoryItemPagePayload payload => ' item ${payload.message.id}',
    final ConnectedChatPagePayload payload =>
      ' ${payload.chatGeneralData.chatName}',
    final String text => ' $text',
    _ => '',
  };
  return 'to ${state.uri}$extra';
}

/// Hosts a people screen the way the app does, under a router whose other
/// routes are stubs: the kit theme in [skin], both languages, reduce motion,
/// the Fuzzzy Cast switch, and the chat list ([chatList]) every person page
/// and Remove read. [extraStubs] adds stub routes (Lock, Open).
Future<GoRouter> pumpPeople(
  WidgetTester tester,
  Widget page, {
  ChatGeneralDataListCubit? chatList,
  FuzzzySkin skin = FuzzzySkin.night,
  bool reduceMotion = false,
  bool castOn = false,
  Locale locale = const Locale('en'),
  List<String> extraStubs = const [],
}) async {
  SharedPreferences.setMockInitialValues({'fuzzzy_cast_enabled': castOn});
  final preferences = PreferencesService(await SharedPreferences.getInstance());

  final stubs = {
    AppRouter.home,
    AppRouter.person,
    AppRouter.personItem,
    AppRouter.personConnected,
    AppRouter.personAnsweredTwice,
    AppRouter.personChecked,
    AppRouter.chatVerify,
    AppRouter.chatInvitation,
    AppRouter.chatAcceptanceExport,
    AppRouter.chatCreate,
    AppRouter.chatConnected,
    ...extraStubs,
  };

  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (_, __) => page),
      for (final path in stubs)
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(body: Text(stubText(state))),
        ),
    ],
  );
  addTearDown(router.dispose);

  final list = chatList ?? chatListOf([personChat()]);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ChatGeneralDataListCubit>.value(value: list),
        BlocProvider(
          create: (_) =>
              FuzzzyCastSettingsCubit(preferencesService: preferences),
        ),
      ],
      child: MaterialApp.router(
        theme: FuzzzyTheme.build(inkPack, skin),
        locale: locale,
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            alwaysUse24HourFormat: true,
          ),
          child: app!,
        ),
      ),
    ),
  );
  await tester.pump();
  return router;
}

/// A chat list cubit that shows [chats] (and which of them are unchecked).
MockChatGeneralDataListCubit chatListOf(
  List<ChatGeneralData> chats, {
  Set<String> unverified = const {},
  StateStatus status = StateStatus.success,
}) {
  final cubit = MockChatGeneralDataListCubit();
  whenListen(
    cubit,
    const Stream<ChatGeneralDataListState>.empty(),
    initialState: ChatGeneralDataListState(
      status: status,
      chatList: chats,
      unverifiedChatIds: unverified,
    ),
  );
  return cubit;
}
