import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

/// Stands in for the user-visible place a finished file moves to (T-0366):
/// answers `publishedPath` for every file, or throws when [failure] is set.
class _FakeUserFileStore extends Fake implements UserFileStore {
  _FakeUserFileStore({this.publishedPath, this.failure});

  final String? publishedPath;
  final Exception? failure;
  final List<({String outputPath, String chatName})> published = [];

  @override
  Future<String> publish({
    required String outputPath,
    required String chatName,
  }) async {
    published.add((outputPath: outputPath, chatName: chatName));
    if (failure != null) throw failure!;
    return publishedPath ?? outputPath;
  }
}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _chatName = 'Bob';
const _publishedPath =
    '/storage/emulated/0/Download/Fuzzzy Seal/Bob/report.pdf.fuzz';

/// A handler whose stream replays [events]; pause/resume/cancel are counted.
class _FakeHandler {
  final List<FileProcessingProgress> events;
  int pauses = 0;
  int resumes = 0;
  int cancels = 0;

  _FakeHandler(this.events);

  FileProcessingHandler get handler => FileProcessingHandler(
        progressStream: Stream.fromIterable(events),
        pause: () => pauses++,
        resume: () => resumes++,
        cancel: () => cancels++,
      );
}

void main() {
  late MockCryptoCoreService mockService;
  late _FakeUserFileStore userFileStore;
  late Directory documents;
  late File input;

  /// Time for the fire-and-forget `_processFile` and its stream to settle.
  const settle = Duration(milliseconds: 150);

  /// [settle] plus the receive side's size-stability probe.
  final settleReceive =
      FileProcessingCubit.inputStabilityProbeDuration + settle;

  setUp(() {
    mockService = MockCryptoCoreService();
    userFileStore = _FakeUserFileStore();
    documents = Directory.systemTemp.createTempSync('file_processing_cubit_');
    input = File(path.join(documents.path, 'report.pdf'))
      ..writeAsStringSync('plain');
    sl.safeRegisterSingleton<AppDocumentsDirectory>(
      AppDocumentsDirectory(directory: documents),
    );
  });

  tearDown(() async {
    await sl.unregister<AppDocumentsDirectory>();
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  String chatFolder() => path.join(documents.path, _chatName);

  FileProcessingCubit<FileEncryptionOption> buildEncrypt() =>
      FileProcessingCubit<FileEncryptionOption>(
        cryptoCoreService: mockService,
        userFileStore: userFileStore,
        processingOption: const FileEncryptionOption(),
      );

  FileProcessingCubit<FileDecryptionOption> buildDecrypt() =>
      FileProcessingCubit<FileDecryptionOption>(
        cryptoCoreService: mockService,
        userFileStore: userFileStore,
        processingOption: const FileDecryptionOption(),
      );

  FileProcessingHandler completingHandler() => _FakeHandler([
        FileProcessingProgress(progress: 0.5),
        FileProcessingProgress.completed(),
      ]).handler;

  void stubEncrypt(CryptoCoreResponse<FileProcessingHandler> response) {
    when(
      () => mockService.encryptFileForChat(
        chatId: any(named: 'chatId'),
        inputPath: any(named: 'inputPath'),
        outputPath: any(named: 'outputPath'),
      ),
    ).thenAnswer((_) async => response);
  }

  void stubDecrypt(CryptoCoreResponse<CryptoCoreReceivedFile> response) {
    when(
      () => mockService.decryptFileForChat(
        chatId: any(named: 'chatId'),
        inputPath: any(named: 'inputPath'),
        outputDirectoryPath: any(named: 'outputDirectoryPath'),
      ),
    ).thenAnswer((_) async => response);
  }

  /// The one processed file of the final state.
  Matcher processedAs(
    FileProcessingStatus status, {
    String? outputFilePath,
    FileProcessingFailureType? failure,
  }) =>
      isA<FileProcessingState>()
          .having((s) => s.currentProcessingFile, 'current', isNull)
          .having((s) => s.toBeProcessedFiles, 'queue', isEmpty)
          .having((s) => s.processedFiles.length, 'processed', 1)
          .having((s) => s.processedFiles.single.status, 'status', status)
          .having(
            (s) => s.processedFiles.single.outputFilePath,
            'outputFilePath',
            outputFilePath,
          )
          .having(
            (s) => s.processedFiles.single.failure?.type,
            'failure',
            failure,
          )
          .having(
            (s) => s.processedFiles.single.isProcessed,
            'isProcessed',
            isTrue,
          );

  // -----------------------------------------------------------------------
  // encrypt (send)
  // -----------------------------------------------------------------------
  group('FileEncryptionOption', () {
    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      'fuzzes through encryptFileForChat into <chat>/<name>.fuzz, streams '
      'progress, completes with the output path',
      setUp: () => stubEncrypt(
        CryptoCoreSuccess(
          _FakeHandler([
            FileProcessingProgress(progress: 0.5),
            FileProcessingProgress.completed(),
          ]).handler,
        ),
      ),
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (cubit) {
        final outputPath = path.join(chatFolder(), 'report.pdf.fuzz');
        verify(
          () => mockService.encryptFileForChat(
            chatId: _chatId,
            inputPath: input.path,
            outputPath: outputPath,
          ),
        ).called(1);
        expect(Directory(chatFolder()).existsSync(), isTrue);
        expect(
          cubit.state,
          processedAs(
            FileProcessingStatus.completed,
            outputFilePath: outputPath,
          ),
        );
        verifyNever(
          () => mockService.decryptFileForChat(
            chatId: any(named: 'chatId'),
            inputPath: any(named: 'inputPath'),
            outputDirectoryPath: any(named: 'outputDirectoryPath'),
          ),
        );
      },
    );

    // T-0366: the finished file is handed to the user-visible store and the
    // row keeps the path the store answers (Downloads/Fuzzzy Seal/<chat> on
    // Android); a store that cannot place it keeps the app's own copy.
    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      'a completed file is published under the chat name and the row keeps '
      'the published path',
      setUp: () {
        userFileStore = _FakeUserFileStore(publishedPath: _publishedPath);
        stubEncrypt(CryptoCoreSuccess(completingHandler()));
      },
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (cubit) {
        expect(
          userFileStore.published.single,
          (
            outputPath: path.join(chatFolder(), 'report.pdf.fuzz'),
            chatName: _chatName,
          ),
        );
        expect(
          cubit.state,
          processedAs(
            FileProcessingStatus.completed,
            outputFilePath: _publishedPath,
          ),
        );
      },
    );

    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      "a store that cannot place the file keeps the app's own path, still "
      'completed',
      setUp: () {
        userFileStore = _FakeUserFileStore(failure: Exception('no storage'));
        stubEncrypt(CryptoCoreSuccess(completingHandler()));
      },
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (cubit) => expect(
        cubit.state,
        processedAs(
          FileProcessingStatus.completed,
          outputFilePath: path.join(chatFolder(), 'report.pdf.fuzz'),
        ),
      ),
    );

    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      "a picker's 'null-' name artefact is dropped from the fuzzed file's "
      'name',
      setUp: () {
        input = File(path.join(documents.path, 'null-20260920-WA0000.jpg'))
          ..writeAsStringSync('jpeg');
        stubEncrypt(CryptoCoreSuccess(completingHandler()));
      },
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (cubit) {
        final outputPath = path.join(chatFolder(), '20260920-WA0000.jpg.fuzz');
        verify(
          () => mockService.encryptFileForChat(
            chatId: _chatId,
            inputPath: input.path,
            outputPath: outputPath,
          ),
        ).called(1);
        expect(
          cubit.state,
          processedAs(
            FileProcessingStatus.completed,
            outputFilePath: outputPath,
          ),
        );
      },
    );

    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      'a prepare failure (locked store) is failed/unknown, nothing streams',
      setUp: () => stubEncrypt(
        const CryptoCoreFailure(CryptoCoreFailureType.storeLocked),
      ),
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (cubit) => expect(
        cubit.state,
        processedAs(
          FileProcessingStatus.failed,
          failure: FileProcessingFailureType.unknown,
        ),
      ),
    );

    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      'a failure event carries isComplete too — errorMessage wins, the file '
      'is failed, never completed',
      setUp: () => stubEncrypt(
        CryptoCoreSuccess(
          _FakeHandler([
            FileProcessingProgress(progress: 0.5),
            FileProcessingProgress.completedWithFailure(
              message: CryptoCoreFailureType.io.name,
              currentProgress: 0.5,
            ),
          ]).handler,
        ),
      ),
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (cubit) {
        expect(
          cubit.state,
          processedAs(
            FileProcessingStatus.failed,
            failure: FileProcessingFailureType.unknown,
          ),
        );
        expect(cubit.state.processedFiles.single.progress, 0.5);
      },
    );

    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      'a cancel event is canceled with no output path',
      setUp: () => stubEncrypt(
        CryptoCoreSuccess(
          _FakeHandler([
            FileProcessingProgress(progress: 0.25),
            FileProcessingProgress.cancelled(),
          ]).handler,
        ),
      ),
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (cubit) => expect(
        cubit.state,
        processedAs(FileProcessingStatus.canceled),
      ),
    );

    test('pause / resume / cancel reach the active handler', () async {
      final fake = _FakeHandler([FileProcessingProgress(progress: 0.1)]);
      stubEncrypt(CryptoCoreSuccess(fake.handler));
      final cubit = buildEncrypt()
        ..addFilesToProcess(
          chatId: _chatId,
          chatName: _chatName,
          filePaths: [input.path],
        );
      await Future<void>.delayed(settle);
      cubit
        ..pauseFile()
        ..resumeFile()
        ..cancelFile();
      expect((fake.pauses, fake.resumes, fake.cancels), (1, 1, 1));
      await cubit.close();
    });

    test('files run one after the other, never in parallel', () async {
      final second = File(path.join(documents.path, 'two.bin'))
        ..writeAsStringSync('2');
      final firstDone = Completer<FileProcessingProgress>();
      when(
        () => mockService.encryptFileForChat(
          chatId: any(named: 'chatId'),
          inputPath: input.path,
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer(
        (_) async => CryptoCoreSuccess(
          FileProcessingHandler(
            progressStream: Stream.fromFuture(firstDone.future),
            pause: () {},
            resume: () {},
            cancel: () {},
          ),
        ),
      );
      when(
        () => mockService.encryptFileForChat(
          chatId: any(named: 'chatId'),
          inputPath: second.path,
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer(
        (_) async => CryptoCoreSuccess(
          _FakeHandler([FileProcessingProgress.completed()]).handler,
        ),
      );

      final cubit = buildEncrypt()
        ..addFilesToProcess(
          chatId: _chatId,
          chatName: _chatName,
          filePaths: [input.path, second.path],
        );
      await Future<void>.delayed(settle);
      verifyNever(
        () => mockService.encryptFileForChat(
          chatId: any(named: 'chatId'),
          inputPath: second.path,
          outputPath: any(named: 'outputPath'),
        ),
      );
      expect(cubit.state.currentProcessingFile?.inputFilePath, input.path);

      firstDone.complete(FileProcessingProgress.completed());
      await Future<void>.delayed(settle);
      expect(
        cubit.state.processedFiles.map((f) => f.status),
        everyElement(FileProcessingStatus.completed),
      );
      expect(cubit.state.processedFiles.length, 2);
      await cubit.close();
    });
  });

  // -----------------------------------------------------------------------
  // decrypt (receive)
  // -----------------------------------------------------------------------
  group('FileDecryptionOption', () {
    late File container;

    setUp(() {
      container = File(path.join(documents.path, 'anything.fuzz'))
        ..writeAsStringSync('FUZZ....');
    });

    blocTest<FileProcessingCubit<FileDecryptionOption>, FileProcessingState>(
      'unfuzzes through decryptFileForChat into the chat folder and completes '
      "with the sender's original name",
      setUp: () => stubDecrypt(
        CryptoCoreSuccess(
          CryptoCoreReceivedFile(
            outputPath: path.join(chatFolder(), 'report.pdf'),
            handler: _FakeHandler([
              FileProcessingProgress(progress: 1 / 3),
              FileProcessingProgress(progress: 2 / 3),
              FileProcessingProgress.completed(),
            ]).handler,
          ),
        ),
      ),
      build: buildDecrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [container.path],
      ),
      wait: settleReceive,
      verify: (cubit) {
        verify(
          () => mockService.decryptFileForChat(
            chatId: _chatId,
            inputPath: container.path,
            outputDirectoryPath: chatFolder(),
          ),
        ).called(1);
        expect(
          cubit.state,
          processedAs(
            FileProcessingStatus.completed,
            outputFilePath: path.join(chatFolder(), 'report.pdf'),
          ),
        );
        // T-0366: the unfuzzed file is published like a fuzzed one.
        expect(
          userFileStore.published.single,
          (
            outputPath: path.join(chatFolder(), 'report.pdf'),
            chatName: _chatName,
          ),
        );
      },
    );

    for (final (core, failure) in [
      (CryptoCoreFailureType.replay, FileProcessingFailureType.alreadyUnfuzzed),
      (CryptoCoreFailureType.wrongChat, FileProcessingFailureType.wrongChat),
      (CryptoCoreFailureType.tooOld, FileProcessingFailureType.tooOld),
      (CryptoCoreFailureType.corrupt, FileProcessingFailureType.corrupt),
      (
        CryptoCoreFailureType.unsupportedFormat,
        FileProcessingFailureType.corrupt
      ),
      (CryptoCoreFailureType.io, FileProcessingFailureType.unknown),
    ]) {
      blocTest<FileProcessingCubit<FileDecryptionOption>, FileProcessingState>(
        'prepare failure ${core.name} → ${failure.name}',
        setUp: () => stubDecrypt(CryptoCoreFailure(core)),
        build: buildDecrypt,
        act: (cubit) => cubit.addFilesToProcess(
          chatId: _chatId,
          chatName: _chatName,
          filePaths: [container.path],
        ),
        wait: settleReceive,
        verify: (cubit) => expect(
          cubit.state,
          processedAs(FileProcessingStatus.failed, failure: failure),
        ),
      );
    }

    blocTest<FileProcessingCubit<FileDecryptionOption>, FileProcessingState>(
      'a run failure after prepare is cannotOpenAskResend (the message is '
      'spent) — errorMessage checked before isComplete',
      setUp: () => stubDecrypt(
        CryptoCoreSuccess(
          CryptoCoreReceivedFile(
            outputPath: path.join(chatFolder(), 'report.pdf'),
            handler: _FakeHandler([
              FileProcessingProgress(progress: 0.5),
              FileProcessingProgress.completedWithFailure(
                message: CryptoCoreFailureType.corrupt.name,
                currentProgress: 0.5,
              ),
            ]).handler,
          ),
        ),
      ),
      build: buildDecrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [container.path],
      ),
      wait: settleReceive,
      verify: (cubit) => expect(
        cubit.state,
        processedAs(
          FileProcessingStatus.failed,
          failure: FileProcessingFailureType.cannotOpenAskResend,
        ),
      ),
    );

    blocTest<FileProcessingCubit<FileDecryptionOption>, FileProcessingState>(
      'a cancelled receive stays canceled but carries the cancelled hint (the '
      'message is spent)',
      setUp: () => stubDecrypt(
        CryptoCoreSuccess(
          CryptoCoreReceivedFile(
            outputPath: path.join(chatFolder(), 'report.pdf'),
            handler: _FakeHandler([
              FileProcessingProgress(progress: 0.25),
              FileProcessingProgress.cancelled(),
            ]).handler,
          ),
        ),
      ),
      build: buildDecrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [container.path],
      ),
      wait: settleReceive,
      verify: (cubit) => expect(
        cubit.state,
        processedAs(
          FileProcessingStatus.canceled,
          failure: FileProcessingFailureType.cancelled,
        ),
      ),
    );

    blocTest<FileProcessingCubit<FileDecryptionOption>, FileProcessingState>(
      'a container whose size still changes is stillArriving and is never '
      'prepared',
      build: buildDecrypt,
      act: (cubit) {
        cubit.addFilesToProcess(
          chatId: _chatId,
          chatName: _chatName,
          filePaths: [container.path],
        );
        // Grow the file inside the probe window.
        Timer(
          FileProcessingCubit.inputStabilityProbeDuration ~/ 2,
          () => container.writeAsStringSync('more', mode: FileMode.append),
        );
      },
      wait: settleReceive,
      verify: (cubit) {
        verifyNever(
          () => mockService.decryptFileForChat(
            chatId: any(named: 'chatId'),
            inputPath: any(named: 'inputPath'),
            outputDirectoryPath: any(named: 'outputDirectoryPath'),
          ),
        );
        expect(
          cubit.state,
          processedAs(
            FileProcessingStatus.failed,
            failure: FileProcessingFailureType.stillArriving,
          ),
        );
      },
    );

    blocTest<FileProcessingCubit<FileDecryptionOption>, FileProcessingState>(
      'a missing input is failed/unknown before any core call',
      build: buildDecrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [path.join(documents.path, 'missing.fuzz')],
      ),
      wait: settleReceive,
      verify: (cubit) {
        verifyZeroInteractions(mockService);
        expect(
          cubit.state,
          processedAs(
            FileProcessingStatus.failed,
            failure: FileProcessingFailureType.unknown,
          ),
        );
      },
    );
  });
}
