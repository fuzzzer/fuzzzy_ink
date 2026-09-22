import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockMessageDataRepository extends Mock implements MessageDataRepository {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _blobBody = 'AwEC';
const _blob = '$fuzzIdentificator$_blobBody';

MessageData _storedText({
  required int id,
  required bool isSent,
  String decryptedMessage = 'hi',
}) =>
    MessageData(
      id: id,
      chatId: _chatId,
      type: MessageType.text,
      encryptedMessage: _blobBody,
      decryptedMessage: decryptedMessage,
      sentAt: DateTime(2026, 9, 12, 12, id),
      isSent: isSent,
    );

void main() {
  late MockCryptoCoreService mockService;
  late MockMessageDataRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(_storedText(id: 0, isSent: true));
  });

  setUp(() {
    mockService = MockCryptoCoreService();
    mockRepo = MockMessageDataRepository();
    when(() => mockRepo.newMessageUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockRepo.addMessage(any())).thenAnswer((_) async => 7);
  });

  ConnectedChatCubit build() => ConnectedChatCubit(
        messageDataRepository: mockRepo,
        cryptoCoreService: mockService,
        chatId: _chatId,
      );

  Matcher failedAction(
    ChatActionType actionType,
    ConnectedChatFailureType failureType,
  ) =>
      isA<ConnectedChatState>()
          .having((s) => s.actionStatus, 'actionStatus', StateStatus.failed)
          .having((s) => s.actionType, 'actionType', actionType)
          .having((s) => s.actionFailure?.type, 'failure', failureType)
          .having((s) => s.messages, 'messages', isEmpty);

  // -----------------------------------------------------------------------
  // sendMessage
  // -----------------------------------------------------------------------
  group('sendMessage', () {
    blocTest<ConnectedChatCubit, ConnectedChatState>(
      'fuzzes through encryptText, stores the sealed row, then shows it',
      setUp: () {
        when(
          () => mockService.encryptText(
            chatId: any(named: 'chatId'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) async => const CryptoCoreSuccess(_blob));
      },
      build: build,
      act: (cubit) => cubit.sendMessage(text: 'hello'),
      expect: () => [
        isA<ConnectedChatState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.loading)
            .having(
              (s) => s.actionType,
              'actionType',
              ChatActionType.sendMessage,
            ),
        isA<ConnectedChatState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.success)
            .having((s) => s.messages.length, 'messages', 1)
            .having((s) => s.messages.first.id, 'id', 7)
            .having((s) => s.messages.first.isSent, 'isSent', isTrue)
            .having((s) => s.messages.first.decryptedMessage, 'text', 'hello')
            .having(
              (s) => s.messages.first.encryptedMessage,
              'blob without the Fuzz/ prefix',
              _blobBody,
            ),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockService.encryptText(chatId: _chatId, text: 'hello'),
          () => mockRepo.addMessage(
                any(
                  that: isA<MessageData>()
                      .having((m) => m.chatId, 'chatId', _chatId)
                      .having((m) => m.type, 'type', MessageType.text)
                      .having((m) => m.isSent, 'isSent', isTrue)
                      .having((m) => m.decryptedMessage, 'plaintext', 'hello')
                      .having((m) => m.encryptedMessage, 'blob', _blobBody),
                ),
              ),
        ]);
      },
    );

    blocTest<ConnectedChatCubit, ConnectedChatState>(
      'a core failure is unknown and nothing is stored',
      setUp: () {
        when(
          () => mockService.encryptText(
            chatId: any(named: 'chatId'),
            text: any(named: 'text'),
          ),
        ).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.storeLocked),
        );
      },
      build: build,
      act: (cubit) => cubit.sendMessage(text: 'hello'),
      expect: () => [
        isA<ConnectedChatState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.loading),
        failedAction(
          ChatActionType.sendMessage,
          ConnectedChatFailureType.unknown,
        ),
      ],
      verify: (_) => verifyNever(() => mockRepo.addMessage(any())),
    );
  });

  // -----------------------------------------------------------------------
  // receiveMessage
  // -----------------------------------------------------------------------
  group('receiveMessage', () {
    blocTest<ConnectedChatCubit, ConnectedChatState>(
      'unfuzzes through decryptText and stores the row BEFORE showing it',
      setUp: () {
        when(
          () => mockService.decryptText(
            chatId: any(named: 'chatId'),
            blob: any(named: 'blob'),
          ),
        ).thenAnswer((_) async => const CryptoCoreSuccess('hello'));
      },
      build: build,
      act: (cubit) {
        // The cubit must not have emitted the message when the row is written.
        when(() => mockRepo.addMessage(any())).thenAnswer((_) async {
          expect(cubit.state.messages, isEmpty);
          expect(cubit.state.actionStatus, StateStatus.loading);
          return 7;
        });
        return cubit.receiveMessage(encryptedText: _blobBody);
      },
      expect: () => [
        isA<ConnectedChatState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.loading)
            .having(
              (s) => s.actionType,
              'actionType',
              ChatActionType.receiveMessage,
            ),
        isA<ConnectedChatState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.success)
            .having((s) => s.messages.length, 'messages', 1)
            .having((s) => s.messages.first.id, 'id', 7)
            .having((s) => s.messages.first.isSent, 'isSent', isFalse)
            .having((s) => s.messages.first.decryptedMessage, 'text', 'hello')
            .having(
              (s) => s.messages.first.encryptedMessage,
              'blob',
              _blobBody,
            ),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockService.decryptText(chatId: _chatId, blob: _blob),
          () => mockRepo.addMessage(
                any(
                  that: isA<MessageData>()
                      .having((m) => m.isSent, 'isSent', isFalse)
                      .having((m) => m.decryptedMessage, 'plaintext', 'hello')
                      .having((m) => m.encryptedMessage, 'blob', _blobBody),
                ),
              ),
        ]);
      },
    );

    for (final (coreFailure, uiFailure) in [
      (CryptoCoreFailureType.replay, ConnectedChatFailureType.alreadyUnfuzzed),
      (CryptoCoreFailureType.wrongChat, ConnectedChatFailureType.wrongChat),
      (CryptoCoreFailureType.tooOld, ConnectedChatFailureType.tooOld),
      (CryptoCoreFailureType.corrupt, ConnectedChatFailureType.corrupt),
      (
        CryptoCoreFailureType.unsupportedFormat,
        ConnectedChatFailureType.corrupt
      ),
      (CryptoCoreFailureType.storeLocked, ConnectedChatFailureType.unknown),
      (CryptoCoreFailureType.unknownChat, ConnectedChatFailureType.unknown),
    ]) {
      blocTest<ConnectedChatCubit, ConnectedChatState>(
        '$coreFailure → $uiFailure, history untouched',
        setUp: () {
          when(
            () => mockService.decryptText(
              chatId: any(named: 'chatId'),
              blob: any(named: 'blob'),
            ),
          ).thenAnswer((_) async => CryptoCoreFailure(coreFailure));
        },
        build: build,
        act: (cubit) => cubit.receiveMessage(encryptedText: _blobBody),
        expect: () => [
          isA<ConnectedChatState>().having(
            (s) => s.actionStatus,
            'actionStatus',
            StateStatus.loading,
          ),
          failedAction(ChatActionType.receiveMessage, uiFailure),
        ],
        verify: (_) => verifyNever(() => mockRepo.addMessage(any())),
      );
    }

    blocTest<ConnectedChatCubit, ConnectedChatState>(
      'a storage throw after a successful unfuzz is unknown',
      setUp: () {
        when(
          () => mockService.decryptText(
            chatId: any(named: 'chatId'),
            blob: any(named: 'blob'),
          ),
        ).thenAnswer((_) async => const CryptoCoreSuccess('hello'));
        when(() => mockRepo.addMessage(any())).thenThrow(Exception('isar'));
      },
      build: build,
      act: (cubit) => cubit.receiveMessage(encryptedText: _blobBody),
      expect: () => [
        isA<ConnectedChatState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.loading),
        failedAction(
          ChatActionType.receiveMessage,
          ConnectedChatFailureType.unknown,
        ),
      ],
    );
  });

  // -----------------------------------------------------------------------
  // history
  // -----------------------------------------------------------------------
  group('loadCurrentMessagesPage', () {
    blocTest<ConnectedChatCubit, ConnectedChatState>(
      'shows the repository rows as they come and never re-decrypts',
      setUp: () {
        when(
          () => mockRepo.getMessagesForChatPaginated(
            any(),
            pageSize: any(named: 'pageSize'),
            pageIndex: any(named: 'pageIndex'),
          ),
        ).thenAnswer(
          (_) async => [
            _storedText(id: 2, isSent: false, decryptedMessage: 'reply'),
            _storedText(id: 1, isSent: true, decryptedMessage: 'hello'),
          ],
        );
      },
      build: build,
      act: (cubit) => cubit.loadInitialMessages(),
      expect: () => [
        isA<ConnectedChatState>()
            .having((s) => s.hasFetchedAllMessages, 'fetchedAll', isFalse),
        isA<ConnectedChatState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<ConnectedChatState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having(
          (s) => s.messages.map((m) => m.decryptedMessage).toList(),
          'plaintexts',
          ['reply', 'hello'],
        ),
      ],
      verify: (_) {
        verify(
          () => mockRepo.getMessagesForChatPaginated(
            _chatId,
            pageSize: 8,
            pageIndex: 0,
          ),
        ).called(1);
        verifyZeroInteractions(mockService);
      },
    );

    blocTest<ConnectedChatCubit, ConnectedChatState>(
      'an empty page marks the history as fully fetched',
      setUp: () {
        when(
          () => mockRepo.getMessagesForChatPaginated(
            any(),
            pageSize: any(named: 'pageSize'),
            pageIndex: any(named: 'pageIndex'),
          ),
        ).thenAnswer((_) async => []);
      },
      build: build,
      act: (cubit) => cubit.loadCurrentMessagesPage(),
      expect: () => [
        isA<ConnectedChatState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<ConnectedChatState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.hasFetchedAllMessages, 'fetchedAll', isTrue),
      ],
    );
  });
}
