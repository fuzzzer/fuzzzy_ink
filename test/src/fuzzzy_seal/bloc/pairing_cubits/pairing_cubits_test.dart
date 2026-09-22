import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockChatGeneralDataListRepository extends Mock
    implements ChatGeneralDataListRepository {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _invitation = CryptoCoreInvitation(chatId: _chatId, content: 'Fuzz/inv');
const _acceptance = CryptoCoreAcceptance(chatId: _chatId, content: 'Fuzz/acc');

final _invitedChat = ChatGeneralData(
  chatId: _chatId,
  chatName: 'Alice',
  setupStatus: ChatSetupStatus.invited,
  didAcceptInvitation: false,
);

void main() {
  late MockCryptoCoreService mockService;
  late MockChatGeneralDataListRepository mockChatRepo;

  setUpAll(() {
    registerFallbackValue(_invitedChat);
  });

  setUp(() {
    mockService = MockCryptoCoreService();
    mockChatRepo = MockChatGeneralDataListRepository();
    when(() => mockChatRepo.getChatByName(any())).thenAnswer((_) async => null);
    when(() => mockChatRepo.getChatById(any())).thenAnswer((_) async => null);
    when(() => mockChatRepo.addChat(any())).thenAnswer((_) async {});
    when(() => mockChatRepo.updateChat(any())).thenAnswer((_) async {});
    when(() => mockChatRepo.deleteChat(any())).thenAnswer((_) async {});
  });

  // -----------------------------------------------------------------------
  // ChatCreationCubit
  // -----------------------------------------------------------------------
  group('ChatCreationCubit', () {
    ChatCreationCubit build() => ChatCreationCubit(
          cryptoCoreService: mockService,
          chatGeneralDataListRepository: mockChatRepo,
        );

    blocTest<ChatCreationCubit, ChatCreationState>(
      'creates the invitation on the core, then the chat record',
      setUp: () {
        when(() => mockService.createInvitation(any())).thenAnswer(
          (invocation) async => CryptoCoreSuccess(
            CryptoCoreInvitation(
              chatId: invocation.positionalArguments.first as String,
              content: 'Fuzz/inv',
            ),
          ),
        );
      },
      build: build,
      act: (cubit) => cubit.createChat(chatName: 'Alice'),
      expect: () => [
        isA<ChatCreationState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<ChatCreationState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.chatId, 'chatId', isNotNull)
            .having(
              (s) => s.generatedChatInvitation?.content,
              'invitation',
              'Fuzz/inv',
            ),
      ],
      verify: (cubit) {
        final chatId = cubit.state.chatId!;
        expect(cubit.state.generatedChatInvitation?.chatId, chatId);
        verifyInOrder([
          () => mockService.createInvitation(chatId),
          () => mockChatRepo.addChat(
                any(
                  that: isA<ChatGeneralData>()
                      .having((c) => c.chatId, 'chatId', chatId)
                      .having(
                        (c) => c.setupStatus,
                        'setupStatus',
                        ChatSetupStatus.invited,
                      ),
                ),
              ),
        ]);
      },
    );

    blocTest<ChatCreationCubit, ChatCreationState>(
      'a core failure is unknown and no chat record is written',
      setUp: () {
        when(() => mockService.createInvitation(any())).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.storeLocked),
        );
      },
      build: build,
      act: (cubit) => cubit.createChat(chatName: 'Alice'),
      expect: () => [
        isA<ChatCreationState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<ChatCreationState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having(
              (s) => s.failure?.type,
              'failure',
              ChatCreationFailureType.unknown,
            ),
      ],
      verify: (_) => verifyNever(() => mockChatRepo.addChat(any())),
    );

    blocTest<ChatCreationCubit, ChatCreationState>(
      'an existing name never reaches the core',
      setUp: () {
        when(() => mockChatRepo.getChatByName('Alice'))
            .thenAnswer((_) async => _invitedChat);
      },
      build: build,
      act: (cubit) => cubit.createChat(chatName: 'Alice'),
      expect: () => [
        isA<ChatCreationState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<ChatCreationState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having(
              (s) => s.failure?.type,
              'failure',
              ChatCreationFailureType.existingName,
            ),
      ],
      verify: (_) => verifyNever(() => mockService.createInvitation(any())),
    );
  });

  // -----------------------------------------------------------------------
  // InvitationReaderCubit / AcceptanceReaderCubit
  // -----------------------------------------------------------------------
  group('InvitationReaderCubit', () {
    blocTest<InvitationReaderCubit, InvitationReaderState>(
      're-displays the current invitation',
      setUp: () {
        when(() => mockService.currentInvitation(_chatId))
            .thenAnswer((_) async => const CryptoCoreSuccess(_invitation));
      },
      build: () => InvitationReaderCubit(cryptoCoreService: mockService),
      act: (cubit) => cubit.generateInvitation(chatId: _chatId),
      expect: () => [
        isA<InvitationReaderState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<InvitationReaderState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.invitation?.content, 'content', 'Fuzz/inv'),
      ],
    );

    blocTest<InvitationReaderCubit, InvitationReaderState>(
      'an unknown chat fails with the default failure',
      setUp: () {
        when(() => mockService.currentInvitation(_chatId)).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.unknownChat),
        );
      },
      build: () => InvitationReaderCubit(cryptoCoreService: mockService),
      act: (cubit) => cubit.generateInvitation(chatId: _chatId),
      expect: () => [
        isA<InvitationReaderState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<InvitationReaderState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having((s) => s.failure, 'failure', isNotNull),
      ],
    );
  });

  group('AcceptanceReaderCubit', () {
    blocTest<AcceptanceReaderCubit, AcceptanceReaderState>(
      're-displays the current acceptance',
      setUp: () {
        when(() => mockService.currentAcceptance(_chatId))
            .thenAnswer((_) async => const CryptoCoreSuccess(_acceptance));
      },
      build: () => AcceptanceReaderCubit(cryptoCoreService: mockService),
      act: (cubit) => cubit.generateAcceptance(chatId: _chatId),
      expect: () => [
        isA<AcceptanceReaderState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<AcceptanceReaderState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.acceptance?.content, 'content', 'Fuzz/acc'),
      ],
    );

    blocTest<AcceptanceReaderCubit, AcceptanceReaderState>(
      'a locked store fails with the default failure',
      setUp: () {
        when(() => mockService.currentAcceptance(_chatId)).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.storeLocked),
        );
      },
      build: () => AcceptanceReaderCubit(cryptoCoreService: mockService),
      act: (cubit) => cubit.generateAcceptance(chatId: _chatId),
      expect: () => [
        isA<AcceptanceReaderState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<AcceptanceReaderState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having((s) => s.failure, 'failure', isNotNull),
      ],
    );
  });

  // -----------------------------------------------------------------------
  // InvitationAcceptanceCubit
  // -----------------------------------------------------------------------
  group('InvitationAcceptanceCubit', () {
    InvitationAcceptanceCubit build() => InvitationAcceptanceCubit(
          chatGeneralDataListRepository: mockChatRepo,
          cryptoCoreService: mockService,
        );

    setUp(() {
      when(() => mockService.peekChatId('Fuzz/inv'))
          .thenReturn(const CryptoCoreSuccess(_chatId));
      when(() => mockService.deleteChat(_chatId))
          .thenAnswer((_) async => const CryptoCoreSuccess(null));
    });

    blocTest<InvitationAcceptanceCubit, InvitationAcceptanceState>(
      'peeks the chat id, accepts on the core, then writes a connected chat',
      setUp: () {
        when(
          () => mockService.acceptInvitation(
            chatId: _chatId,
            invitation: 'Fuzz/inv',
          ),
        ).thenAnswer((_) async => const CryptoCoreSuccess(_acceptance));
      },
      build: build,
      act: (cubit) => cubit.acceptInvitation(
        invitationContent: 'Fuzz/inv',
        chatName: 'Bob',
      ),
      expect: () => [
        isA<InvitationAcceptanceState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<InvitationAcceptanceState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.chatData?.chatId, 'chatId', _chatId)
            .having(
              (s) => s.chatData?.setupStatus,
              'setupStatus',
              ChatSetupStatus.connected,
            )
            .having(
              (s) => s.chatData?.didAcceptInvitation,
              'didAcceptInvitation',
              true,
            )
            .having(
              (s) => s.generatedAcceptance?.content,
              'acceptance',
              'Fuzz/acc',
            ),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockService.peekChatId('Fuzz/inv'),
          () => mockChatRepo.getChatById(_chatId),
          () => mockService.deleteChat(_chatId),
          () => mockService.acceptInvitation(
                chatId: _chatId,
                invitation: 'Fuzz/inv',
              ),
          () => mockChatRepo.addChat(any()),
        ]);
      },
    );

    for (final type in [
      CryptoCoreFailureType.unsupportedFormat,
      CryptoCoreFailureType.invalidSignature,
      CryptoCoreFailureType.corrupt,
    ]) {
      blocTest<InvitationAcceptanceCubit, InvitationAcceptanceState>(
        '$type from the core is invalidInvitation, no chat written',
        setUp: () {
          when(
            () => mockService.acceptInvitation(
              chatId: _chatId,
              invitation: 'Fuzz/inv',
            ),
          ).thenAnswer((_) async => CryptoCoreFailure(type));
        },
        build: build,
        act: (cubit) => cubit.acceptInvitation(
          invitationContent: 'Fuzz/inv',
          chatName: 'Bob',
        ),
        expect: () => [
          isA<InvitationAcceptanceState>()
              .having((s) => s.status, 'status', StateStatus.loading),
          isA<InvitationAcceptanceState>()
              .having((s) => s.status, 'status', StateStatus.failed)
              .having(
                (s) => s.failure?.type,
                'failure',
                ChatCreationFailureType.invalidInvitation,
              ),
        ],
        verify: (_) => verifyNever(() => mockChatRepo.addChat(any())),
      );
    }

    blocTest<InvitationAcceptanceCubit, InvitationAcceptanceState>(
      'a blob that names no chat is invalidInvitation before the core',
      setUp: () {
        when(() => mockService.peekChatId('garbage')).thenReturn(
          const CryptoCoreFailure(CryptoCoreFailureType.unsupportedFormat),
        );
      },
      build: build,
      act: (cubit) => cubit.acceptInvitation(
        invitationContent: 'garbage',
        chatName: 'Bob',
      ),
      expect: () => [
        isA<InvitationAcceptanceState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<InvitationAcceptanceState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having(
              (s) => s.failure?.type,
              'failure',
              ChatCreationFailureType.invalidInvitation,
            ),
      ],
      verify: (_) {
        verifyNever(
          () => mockService.acceptInvitation(
            chatId: any(named: 'chatId'),
            invitation: any(named: 'invitation'),
          ),
        );
      },
    );

    blocTest<InvitationAcceptanceCubit, InvitationAcceptanceState>(
      'an invitation for a chat this device already has is ownInvitation',
      setUp: () {
        when(() => mockChatRepo.getChatById(_chatId))
            .thenAnswer((_) async => _invitedChat);
      },
      build: build,
      act: (cubit) => cubit.acceptInvitation(
        invitationContent: 'Fuzz/inv',
        chatName: 'Bob',
      ),
      expect: () => [
        isA<InvitationAcceptanceState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<InvitationAcceptanceState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having(
              (s) => s.failure?.type,
              'failure',
              ChatCreationFailureType.ownInvitation,
            ),
      ],
      verify: (_) {
        verifyNever(() => mockService.deleteChat(any()));
        verifyNever(
          () => mockService.acceptInvitation(
            chatId: any(named: 'chatId'),
            invitation: any(named: 'invitation'),
          ),
        );
      },
    );

    blocTest<InvitationAcceptanceCubit, InvitationAcceptanceState>(
      'an existing chat name never reaches the core',
      setUp: () {
        when(() => mockChatRepo.getChatByName('Bob'))
            .thenAnswer((_) async => _invitedChat);
      },
      build: build,
      act: (cubit) => cubit.acceptInvitation(
        invitationContent: 'Fuzz/inv',
        chatName: 'Bob',
      ),
      expect: () => [
        isA<InvitationAcceptanceState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<InvitationAcceptanceState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having(
              (s) => s.failure?.type,
              'failure',
              ChatCreationFailureType.existingName,
            ),
      ],
      verify: (_) => verifyNever(() => mockService.peekChatId(any())),
    );
  });

  // -----------------------------------------------------------------------
  // HandshakeCubit
  // -----------------------------------------------------------------------
  group('HandshakeCubit', () {
    HandshakeCubit build() => HandshakeCubit(
          cryptoCoreService: mockService,
          chatGeneralDataListRepository: mockChatRepo,
        );

    blocTest<HandshakeCubit, HandshakeState>(
      'completes on the core, then marks the chat connected',
      setUp: () {
        when(
          () => mockService.completeHandshake(
            chatId: _chatId,
            acceptance: 'Fuzz/acc',
          ),
        ).thenAnswer((_) async => const CryptoCoreSuccess(null));
        when(() => mockChatRepo.getChatById(_chatId))
            .thenAnswer((_) async => _invitedChat);
      },
      build: build,
      act: (cubit) => cubit.completeHandshake(
        acceptanceContent: 'Fuzz/acc',
        chatId: _chatId,
      ),
      expect: () => [
        isA<HandshakeState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<HandshakeState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.chatData?.chatId, 'chatId', _chatId),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockService.completeHandshake(
                chatId: _chatId,
                acceptance: 'Fuzz/acc',
              ),
          () => mockChatRepo.updateChat(
                any(
                  that: isA<ChatGeneralData>().having(
                    (c) => c.setupStatus,
                    'setupStatus',
                    ChatSetupStatus.connected,
                  ),
                ),
              ),
        ]);
      },
    );

    for (final (core, ui) in [
      (
        CryptoCoreFailureType.invitationAlreadyUsed,
        ChatCreationFailureType.invitationAlreadyUsed
      ),
      (CryptoCoreFailureType.wrongChat, ChatCreationFailureType.wrongChat),
      (
        CryptoCoreFailureType.unsupportedFormat,
        ChatCreationFailureType.invalidAcceptance
      ),
      (
        CryptoCoreFailureType.invalidSignature,
        ChatCreationFailureType.invalidAcceptance
      ),
      (
        CryptoCoreFailureType.corrupt,
        ChatCreationFailureType.invalidAcceptance
      ),
      (CryptoCoreFailureType.storeLocked, ChatCreationFailureType.unknown),
      (CryptoCoreFailureType.unknownChat, ChatCreationFailureType.unknown),
    ]) {
      blocTest<HandshakeCubit, HandshakeState>(
        '$core from the core is $ui and the chat stays as it was',
        setUp: () {
          when(
            () => mockService.completeHandshake(
              chatId: _chatId,
              acceptance: 'Fuzz/acc',
            ),
          ).thenAnswer((_) async => CryptoCoreFailure(core));
        },
        build: build,
        act: (cubit) => cubit.completeHandshake(
          acceptanceContent: 'Fuzz/acc',
          chatId: _chatId,
        ),
        expect: () => [
          isA<HandshakeState>()
              .having((s) => s.status, 'status', StateStatus.loading),
          isA<HandshakeState>()
              .having((s) => s.status, 'status', StateStatus.failed)
              .having((s) => s.failure?.type, 'failure', ui),
        ],
        verify: (_) => verifyNever(() => mockChatRepo.updateChat(any())),
      );
    }
  });

  // -----------------------------------------------------------------------
  // ChatGeneralDataListCubit.deleteChat
  // -----------------------------------------------------------------------
  group('ChatGeneralDataListCubit.deleteChat', () {
    ChatGeneralDataListCubit build() {
      when(() => mockChatRepo.chatListUpdates)
          .thenAnswer((_) => const Stream.empty());
      return ChatGeneralDataListCubit(
        cryptoCoreService: mockService,
        chatRepository: mockChatRepo,
      );
    }

    blocTest<ChatGeneralDataListCubit, ChatGeneralDataListState>(
      'deletes the core state before the chat record',
      setUp: () {
        when(() => mockService.deleteChat(_chatId))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: build,
      act: (cubit) => cubit.deleteChat(chatId: _chatId),
      expect: () => [
        isA<ChatGeneralDataListState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.loading),
        isA<ChatGeneralDataListState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.success)
            .having((s) => s.actionType, 'actionType', ActionType.delete),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockService.deleteChat(_chatId),
          () => mockChatRepo.deleteChat(_chatId),
        ]);
      },
    );

    blocTest<ChatGeneralDataListCubit, ChatGeneralDataListState>(
      'a locked store keeps the chat record',
      setUp: () {
        when(() => mockService.deleteChat(_chatId)).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.storeLocked),
        );
      },
      build: build,
      act: (cubit) => cubit.deleteChat(chatId: _chatId),
      expect: () => [
        isA<ChatGeneralDataListState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.loading),
        isA<ChatGeneralDataListState>()
            .having((s) => s.actionStatus, 'actionStatus', StateStatus.failed)
            .having((s) => s.actionFailure, 'actionFailure', isNotNull),
      ],
      verify: (_) => verifyNever(() => mockChatRepo.deleteChat(any())),
    );
  });
}
