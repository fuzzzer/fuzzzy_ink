import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockChatArchiveRepository extends Mock implements ChatArchiveRepository {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _chatName = 'Alice';
const _password = 'correct horse battery staple';
const _outputPath = '/tmp/fuzzzy_ink_archive_2026-09-13.fuzz';

void main() {
  late MockChatArchiveRepository mockRepository;

  setUp(() {
    mockRepository = MockChatArchiveRepository();
  });

  ChatArchiveExportCubit build() =>
      ChatArchiveExportCubit(chatArchiveRepository: mockRepository);

  void stubExport(ChatArchiveResponse<void> response) {
    when(
      () => mockRepository.exportChat(
        chatId: any(named: 'chatId'),
        chatName: any(named: 'chatName'),
        password: any(named: 'password'),
        outputPath: any(named: 'outputPath'),
      ),
    ).thenAnswer((_) async => response);
  }

  Future<void> export(ChatArchiveExportCubit cubit) => cubit.exportChat(
        chatId: _chatId,
        chatName: _chatName,
        password: _password,
        outputPath: _outputPath,
      );

  Matcher status(StateStatus status, {ChatArchiveExportFailureType? failure}) =>
      isA<ChatArchiveExportState>()
          .having((s) => s.status, 'status', status)
          .having((s) => s.failureType, 'failureType', failure);

  group('ChatArchiveExportCubit', () {
    blocTest<ChatArchiveExportCubit, ChatArchiveExportState>(
      'hands the chat, password and output path to the repository and '
      'succeeds when it does',
      setUp: () => stubExport(const ChatArchiveSuccess(null)),
      build: build,
      act: export,
      expect: () => [
        status(StateStatus.loading),
        status(StateStatus.success),
      ],
      verify: (_) {
        verify(
          () => mockRepository.exportChat(
            chatId: _chatId,
            chatName: _chatName,
            password: _password,
            outputPath: _outputPath,
          ),
        ).called(1);
      },
    );

    for (final type in ChatArchiveExportFailureType.values) {
      blocTest<ChatArchiveExportCubit, ChatArchiveExportState>(
        'a ${type.name} failure fails with that type',
        setUp: () => stubExport(ChatArchiveFailure(type)),
        build: build,
        act: export,
        expect: () => [
          status(StateStatus.loading),
          status(StateStatus.failed, failure: type),
        ],
      );
    }

    blocTest<ChatArchiveExportCubit, ChatArchiveExportState>(
      'a later success clears the failure',
      setUp: () => stubExport(
        const ChatArchiveFailure(ChatArchiveExportFailureType.storeLocked),
      ),
      build: build,
      act: (cubit) async {
        await export(cubit);
        stubExport(const ChatArchiveSuccess(null));
        await export(cubit);
      },
      expect: () => [
        status(StateStatus.loading),
        status(
          StateStatus.failed,
          failure: ChatArchiveExportFailureType.storeLocked,
        ),
        status(
          StateStatus.loading,
          failure: ChatArchiveExportFailureType.storeLocked,
        ),
        status(StateStatus.success),
      ],
    );
  });
}
