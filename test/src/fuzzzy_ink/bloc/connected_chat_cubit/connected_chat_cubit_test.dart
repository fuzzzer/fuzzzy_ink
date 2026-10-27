import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockMessageDataRepository extends Mock implements MessageDataRepository {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _blobBody = 'AwEC';

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
  late MockMessageDataRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(_storedText(id: 0, isSent: true));
  });

  setUp(() {
    mockRepo = MockMessageDataRepository();
    when(() => mockRepo.newMessageUpdates)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockRepo.addMessage(any())).thenAnswer((_) async => 7);
  });

  ConnectedChatCubit build() => ConnectedChatCubit(
        messageDataRepository: mockRepo,
        chatId: _chatId,
      );

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

  // -----------------------------------------------------------------------
  // reloadMessages
  // -----------------------------------------------------------------------
  group('reloadMessages', () {
    test(
        'reads the loaded pages again from the newest row and replaces the '
        'list', () async {
      final cubit = ConnectedChatCubit(
        messageDataRepository: mockRepo,
        chatId: _chatId,
        messagesPerPage: 2,
      );
      addTearDown(cubit.close);
      var rows = [
        for (var id = 5; id >= 1; id--) _storedText(id: id, isSent: true),
      ];
      when(
        () => mockRepo.getMessagesForChatPaginated(
          _chatId,
          pageSize: any(named: 'pageSize'),
          pageIndex: any(named: 'pageIndex'),
        ),
      ).thenAnswer((invocation) async {
        final size = invocation.namedArguments[#pageSize] as int;
        final index = invocation.namedArguments[#pageIndex] as int;
        return rows.skip(size * index).take(size).toList();
      });

      await cubit.loadInitialMessages();
      await cubit.loadOlderMessages();
      expect(cubit.state.messages.map((m) => m.id), [5, 4, 3, 2]);

      // Lock added a row while the page was away.
      rows = [_storedText(id: 6, isSent: true), ...rows];
      await cubit.reloadMessages();

      expect(cubit.state.status, StateStatus.success);
      expect(cubit.state.messages.map((m) => m.id), [6, 5, 4, 3]);
    });
  });
}
