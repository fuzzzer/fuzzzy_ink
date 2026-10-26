import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockChatGeneralDataListRepository extends Mock
    implements ChatGeneralDataListRepository {}

class MockMessageDataRepository extends Mock implements MessageDataRepository {}

class MockUserFileStore extends Mock implements UserFileStore {}

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
    when(() => mockChatRepo.rememberPairedAcceptance(any(), any()))
        .thenAnswer((_) async {});
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

    group('checkInvitation reads an invite without accepting it', () {
      test('a good invite from someone new', () async {
        expect(await build().checkInvitation('Fuzz/inv'), InvitationCheck.good);
        verifyNever(
          () => mockService.acceptInvitation(
            chatId: any(named: 'chatId'),
            invitation: any(named: 'invitation'),
          ),
        );
        verifyNever(() => mockChatRepo.addChat(any()));
      });

      test('an invite this phone made is its own', () async {
        when(() => mockChatRepo.getChatById(_chatId))
            .thenAnswer((_) async => _invitedChat);
        expect(
          await build().checkInvitation('Fuzz/inv'),
          InvitationCheck.ownInvitation,
        );
      });

      test('an invite this phone accepted is already connected', () async {
        when(() => mockChatRepo.getChatById(_chatId)).thenAnswer(
          (_) async => _invitedChat.copyWith(
            setupStatus: ChatSetupStatus.connected,
            didAcceptInvitation: true,
          ),
        );
        expect(
          await build().checkInvitation('Fuzz/inv'),
          InvitationCheck.alreadyConnected,
        );
      });

      for (final type in [
        CryptoCoreFailureType.unsupportedFormat,
        CryptoCoreFailureType.corrupt,
      ]) {
        test('an unreadable invite ($type) is damaged', () async {
          when(() => mockService.peekChatId('Fuzz/bad'))
              .thenReturn(CryptoCoreFailure(type));
          expect(
            await build().checkInvitation('Fuzz/bad'),
            InvitationCheck.damaged,
          );
        });
      }
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
          () => mockChatRepo.rememberPairedAcceptance(_chatId, 'Fuzz/acc'),
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
        verify: (_) {
          verifyNever(() => mockChatRepo.updateChat(any()));
          verifyNever(
            () => mockChatRepo.rememberPairedAcceptance(any(), any()),
          );
        },
      );
    }
  });

  // -----------------------------------------------------------------------
  // ChatGeneralDataListCubit: the "not verified" mark
  // -----------------------------------------------------------------------
  group('ChatGeneralDataListCubit verification', () {
    const verifiedId = '11111111-1111-4111-8111-111111111111';
    const lockedId = '22222222-2222-4222-8222-222222222222';
    final chats = [
      _invitedChat,
      ChatGeneralData(
        chatId: verifiedId,
        chatName: 'Verified',
        setupStatus: ChatSetupStatus.connected,
        didAcceptInvitation: true,
      ),
      ChatGeneralData(
        chatId: lockedId,
        chatName: 'Unreadable',
        setupStatus: ChatSetupStatus.connected,
        didAcceptInvitation: true,
      ),
      ChatGeneralData(
        chatId: '33333333-3333-4333-8333-333333333333',
        chatName: 'Unverified',
        setupStatus: ChatSetupStatus.connected,
        didAcceptInvitation: false,
      ),
    ];

    ChatGeneralDataListCubit build() {
      when(() => mockChatRepo.chatListUpdates)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockChatRepo.getAllChats()).thenAnswer((_) async => chats);
      when(() => mockService.isVerified(any()))
          .thenAnswer((_) async => const CryptoCoreSuccess(false));
      when(() => mockService.isVerified(verifiedId))
          .thenAnswer((_) async => const CryptoCoreSuccess(true));
      when(() => mockService.isVerified(lockedId)).thenAnswer(
        (_) async => const CryptoCoreFailure(CryptoCoreFailureType.storeLocked),
      );
      return ChatGeneralDataListCubit(
        cryptoCoreService: mockService,
        chatRepository: mockChatRepo,
        messageDataRepository: MockMessageDataRepository(),
        userFileStore: MockUserFileStore(),
      );
    }

    blocTest<ChatGeneralDataListCubit, ChatGeneralDataListState>(
      'marks every connected chat that is not verified, or unreadable; '
      'never a chat still waiting for its acceptance',
      build: build,
      act: (cubit) => cubit.fetchChats(),
      skip: 1,
      expect: () => [
        isA<ChatGeneralDataListState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having(
          (s) => s.unverifiedChatIds,
          'unverifiedChatIds',
          {lockedId, '33333333-3333-4333-8333-333333333333'},
        ),
      ],
      verify: (_) => verifyNever(() => mockService.isVerified(_chatId)),
    );

    blocTest<ChatGeneralDataListCubit, ChatGeneralDataListState>(
      'refreshVerification picks up a chat verified meanwhile',
      build: build,
      act: (cubit) async {
        await cubit.fetchChats();
        when(() => mockService.isVerified(lockedId))
            .thenAnswer((_) async => const CryptoCoreSuccess(true));
        await cubit.refreshVerification();
      },
      skip: 2,
      expect: () => [
        isA<ChatGeneralDataListState>().having(
          (s) => s.unverifiedChatIds,
          'unverifiedChatIds',
          {'33333333-3333-4333-8333-333333333333'},
        ),
      ],
    );
  });

  // -----------------------------------------------------------------------
  // ChatGeneralDataListCubit.deleteChat
  // -----------------------------------------------------------------------
  group('ChatGeneralDataListCubit.deleteChat', () {
    late MockMessageDataRepository mockMessages;
    late MockUserFileStore mockFiles;

    setUp(() {
      mockMessages = MockMessageDataRepository();
      mockFiles = MockUserFileStore();
      when(() => mockMessages.getFilePathsForChat(_chatId))
          .thenAnswer((_) async => ['chats/Alice (6f1e9b2c)/a.pdf.fuzz']);
      when(() => mockMessages.deleteAllMessagesForChat(_chatId))
          .thenAnswer((_) async {});
      when(
        () => mockFiles.deleteChatFiles(
          chatName: any(named: 'chatName'),
          chatId: any(named: 'chatId'),
          storedPaths: any(named: 'storedPaths'),
        ),
      ).thenAnswer((_) async {});
    });

    ChatGeneralDataListCubit build() {
      when(() => mockChatRepo.chatListUpdates)
          .thenAnswer((_) => const Stream.empty());
      return ChatGeneralDataListCubit(
        cryptoCoreService: mockService,
        chatRepository: mockChatRepo,
        messageDataRepository: mockMessages,
        userFileStore: mockFiles,
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
      "deletes the chat's sealed files (its folder and every row's) and its "
      'rows with it',
      setUp: () {
        when(() => mockService.deleteChat(_chatId))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: build,
      seed: () => ChatGeneralDataListState(
        status: StateStatus.success,
        chatList: [_invitedChat],
      ),
      act: (cubit) => cubit.deleteChat(chatId: _chatId),
      verify: (_) {
        verifyInOrder([
          () => mockService.deleteChat(_chatId),
          () => mockFiles.deleteChatFiles(
                chatName: 'Alice',
                chatId: _chatId,
                storedPaths: ['chats/Alice (6f1e9b2c)/a.pdf.fuzz'],
              ),
          () => mockMessages.deleteAllMessagesForChat(_chatId),
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
      verify: (_) {
        verifyNever(() => mockChatRepo.deleteChat(any()));
        verifyNever(
          () => mockFiles.deleteChatFiles(
            chatName: any(named: 'chatName'),
            chatId: any(named: 'chatId'),
            storedPaths: any(named: 'storedPaths'),
          ),
        );
      },
    );
  });
}
