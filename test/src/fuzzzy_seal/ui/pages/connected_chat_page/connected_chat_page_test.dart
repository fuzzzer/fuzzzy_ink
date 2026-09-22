import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockUserFileStore extends Mock implements UserFileStore {}

class MockMessageDataRepository extends Mock implements MessageDataRepository {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

MessageData _row(int id) => MessageData(
      id: id,
      chatId: _chatId,
      type: MessageType.text,
      encryptedMessage: 'blob$id',
      decryptedMessage: 'text $id',
      sentAt: DateTime(2026, 9, 12, 12, id),
      isSent: id.isEven,
    );

void main() {
  late MockCryptoCoreService mockService;
  late MockMessageDataRepository mockRepo;

  setUp(() {
    mockService = MockCryptoCoreService();
    mockRepo = MockMessageDataRepository();
    when(() => mockRepo.newMessageUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(
      () => mockRepo.getMessagesForChatPaginated(
        any(),
        pageSize: any(named: 'pageSize'),
        pageIndex: any(named: 'pageIndex'),
      ),
    ).thenAnswer(
      (invocation) async {
        final page = invocation.namedArguments[#pageIndex] as int;
        return List.generate(8, (i) => _row(page * 8 + i));
      },
    );
    when(
      () => mockService.decryptText(
        chatId: any(named: 'chatId'),
        blob: any(named: 'blob'),
      ),
    ).thenAnswer(
      (_) async => const CryptoCoreFailure(CryptoCoreFailureType.corrupt),
    );
  });

  group('shouldToastFailure (the connected chat page listener predicate)', () {
    test(
        'a failed paste toasts once; the loads of the next scroll-up stay '
        'silent although actionStatus is sticky', () async {
      final cubit = ConnectedChatCubit(
        messageDataRepository: mockRepo,
        cryptoCoreService: mockService,
        chatId: _chatId,
      );
      addTearDown(cubit.close);

      // Replay the page's listener over the real state stream.
      final toasts = <String>[];
      var previous = cubit.state;
      final subscription = cubit.stream.listen((current) {
        if (shouldToastFailure(previous, current)) {
          toasts.add(
            current.status.isFailed
                ? 'load'
                : 'action:${current.actionFailure?.type.name}',
          );
        }
        previous = current;
      });
      addTearDown(subscription.cancel);

      await cubit.loadInitialMessages();
      await cubit.receiveMessage(encryptedText: 'garbage');
      await pumpEventQueue();
      expect(toasts, ['action:corrupt']);

      await cubit.loadOlderMessages();
      await cubit.loadOlderMessages();
      await pumpEventQueue();
      expect(cubit.state.messages.length, 24);
      expect(cubit.state.actionStatus, StateStatus.failed, reason: 'sticky');
      expect(toasts, ['action:corrupt'], reason: 'no re-toast on scroll-up');

      // A second failed paste is a new transition into failed → one more.
      await cubit.receiveMessage(encryptedText: 'garbage');
      await pumpEventQueue();
      expect(toasts, ['action:corrupt', 'action:corrupt']);
    });

    test('a load failure toasts on its transition only', () {
      const idle =
          ConnectedChatState(status: StateStatus.success, messages: []);
      const failed =
          ConnectedChatState(status: StateStatus.failed, messages: []);
      const failedAgain = ConnectedChatState(
        status: StateStatus.failed,
        messages: [],
        actionStatus: StateStatus.loading,
      );

      expect(shouldToastFailure(idle, failed), isTrue);
      expect(shouldToastFailure(failed, failedAgain), isFalse);
      expect(shouldToastFailure(failed, idle), isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // openSafetyNumber (the inviter's entry point after the handshake)
  // -----------------------------------------------------------------------
  group('openSafetyNumber', () {
    testWidgets(
        'pushes the safety-number page over the chat and reloads the shield '
        'cubit when it pops', (tester) async {
      SharedPreferences.setMockInitialValues({'has_completed_tutorial': true});
      sl.safeRegisterSingleton<PreferencesService>(
        PreferencesService(await SharedPreferences.getInstance()),
      );
      sl.safeRegisterSingleton<MessageDataRepository>(mockRepo);
      sl.safeRegisterSingleton<CryptoCoreService>(mockService);
      when(() => mockService.safetyNumber(_chatId))
          .thenAnswer((_) async => const CryptoCoreSuccess('12345 67890'));
      when(() => mockService.isVerified(_chatId))
          .thenAnswer((_) async => const CryptoCoreSuccess(false));

      final chat = ChatGeneralData(
        chatId: _chatId,
        chatName: 'Alice',
        setupStatus: ChatSetupStatus.connected,
        didAcceptInvitation: false,
      );
      final router = GoRouter(
        initialLocation: AppRouter.chatConnected,
        routes: [
          GoRoute(
            path: AppRouter.chatConnected,
            builder: (_, __) => ConnectedChatPage(
              payload: ConnectedChatPagePayload(
                chatGeneralData: chat,
                openSafetyNumber: true,
              ),
            ),
          ),
          GoRoute(
            path: AppRouter.chatVerify,
            builder: (_, __) => const Scaffold(body: Text('verify page')),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<FileProcessingCubit<FileEncryptionOption>>(
              create: (_) => FileProcessingCubit<FileEncryptionOption>(
                processingOption: const FileEncryptionOption(),
                cryptoCoreService: mockService,
                userFileStore: MockUserFileStore(),
              ),
            ),
            BlocProvider<FileProcessingCubit<FileDecryptionOption>>(
              create: (_) => FileProcessingCubit<FileDecryptionOption>(
                processingOption: const FileDecryptionOption(),
                cryptoCoreService: mockService,
                userFileStore: MockUserFileStore(),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
            localizationsDelegates:
                FuzzzySealLocalizations.localizationsDelegates,
            supportedLocales: FuzzzySealLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('verify page'), findsOneWidget);
      verify(() => mockService.isVerified(_chatId)).called(1);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('verify page'), findsNothing);
      verify(() => mockService.isVerified(_chatId)).called(1);
    });
  });
}
