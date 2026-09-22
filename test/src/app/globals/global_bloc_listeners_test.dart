import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockUserFileStore extends Mock implements UserFileStore {}

class MockMessageDataRepository extends Mock implements MessageDataRepository {}

class MockFuzzyAuthStore extends Mock implements FuzzyAuthStore {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

FileProcessingData _received(
  String name, {
  FileProcessingFailureType? failure,
}) =>
    FileProcessingData(
      chatId: _chatId,
      chatName: 'Bob',
      inputFilePath: '/received/$name',
      encryptionStartTime: DateTime(2026, 9, 13),
      outputFilePath: failure == null ? '/documents/Bob/$name' : null,
      status: failure == null
          ? FileProcessingStatus.completed
          : FileProcessingStatus.failed,
      failure: failure == null ? null : FileProcessingFailure(type: failure),
    );

/// T-0334: the "Failed to process files" snackbar was gated on a change of
/// the failed list's *length*; the first failure (previous list `null`) and
/// every later single-file batch (length 1 → 1) were silent.
void main() {
  late MockMessageDataRepository mockRepo;
  late MockFuzzyAuthStore authStore;
  late ChatFileInjectorCubit injector;
  late FuzzzySealLocalizations l10n;

  setUpAll(() {
    registerFallbackValue(
      MessageData(
        id: 0,
        type: MessageType.file,
        chatId: _chatId,
        encryptedMessage: '',
        decryptedMessage: '',
        sentAt: DateTime(2026),
        isSent: false,
      ),
    );
  });

  setUp(() {
    mockRepo = MockMessageDataRepository();
    when(
      () => mockRepo.addMessage(
        any(),
        notifyListeners: any(named: 'notifyListeners'),
      ),
    ).thenAnswer((_) async => 1);

    authStore = MockFuzzyAuthStore();
    whenListen(
      authStore,
      const Stream<FuzzyAuthState>.empty(),
      initialState: const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.noAuthRequired),
    );

    injector = ChatFileInjectorCubit(messageDataRepository: mockRepo);
  });

  tearDown(() => injector.close());

  Future<void> pumpListeners(WidgetTester tester) async {
    final mockService = MockCryptoCoreService();
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
          BlocProvider<ChatFileInjectorCubit>.value(value: injector),
          BlocProvider<FuzzyAuthStore>.value(value: authStore),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          localizationsDelegates: FuzzzySealLocalizations.localizationsDelegates,
          supportedLocales: FuzzzySealLocalizations.supportedLocales,
          home: const GlobalBlocListeners(
            child: Scaffold(body: Text('chat')),
          ),
        ),
      ),
    );
    l10n = FuzzzySealLocalizations.of(navigatorKey.currentContext!)!;
  }

  Future<void> inject(
    WidgetTester tester,
    List<FileProcessingData> files,
  ) async {
    await injector.injectProcessedFile(
      processedFiles: files,
      filesAreEncrypted: false,
    );
    await tester.pump();
  }

  Future<void> dismissSnackBar(WidgetTester tester) async {
    scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  testWidgets(
      'a failed receive shows the snackbar with the file-specific reason, '
      'on the first failure and on the next one', (tester) async {
    await pumpListeners(tester);

    await inject(tester, [
      _received('a.fuzz', failure: FileProcessingFailureType.corrupt),
    ]);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.textContaining(
        '${l10n.failedToProcessFiles}: [a.fuzz (${l10n.fileCorrupt})]',
      ),
      findsOneWidget,
    );
    await dismissSnackBar(tester);
    expect(find.byType(SnackBar), findsNothing);

    await inject(tester, [
      _received('a.fuzz', failure: FileProcessingFailureType.alreadyUnfuzzed),
    ]);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining(l10n.alreadyReceived), findsOneWidget);
    await dismissSnackBar(tester);
  });

  testWidgets('two consecutive failures queue two snackbars', (tester) async {
    await pumpListeners(tester);

    await inject(tester, [
      _received('a.fuzz', failure: FileProcessingFailureType.corrupt),
    ]);
    await inject(tester, [
      _received('b.fuzz', failure: FileProcessingFailureType.tooOld),
    ]);
    expect(find.textContaining(l10n.fileCorrupt), findsOneWidget);

    await dismissSnackBar(tester);
    expect(find.textContaining(l10n.fileTooOld), findsOneWidget);
    await dismissSnackBar(tester);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a clean batch and an empty batch show nothing', (tester) async {
    await pumpListeners(tester);

    await inject(tester, [_received('ok.bin')]);
    await inject(tester, const []);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    verify(() => mockRepo.addMessage(any(), notifyListeners: true)).called(1);
  });
}
