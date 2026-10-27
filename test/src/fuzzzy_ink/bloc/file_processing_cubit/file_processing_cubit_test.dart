import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _chatName = 'Bob';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCryptoCoreService mockService;
  late UserFileStore userFileStore;
  late Directory documents;
  late Directory support;
  late Directory temporary;
  late File input;
  final markedForBackupExclusion = <String>[];

  /// Time for the fire-and-forget `_processFile` and its stream to settle.
  const settle = Duration(milliseconds: 150);

  /// [settle] plus the receive side's size-stability probe.
  final settleReceive =
      FileProcessingCubit.inputStabilityProbeDuration + settle;

  setUp(() {
    markedForBackupExclusion.clear();
    mockService = MockCryptoCoreService();
    documents = Directory.systemTemp.createTempSync('file_processing_cubit_');
    support = Directory(path.join(documents.path, 'support'))..createSync();
    temporary = Directory(path.join(documents.path, 'tmp'))..createSync();
    userFileStore = UserFileStore(
      supportDirectoryPath: support.path,
      temporaryDirectoryPath: temporary.path,
      documentsDirectoryPath: documents.path,
    );
    input = File(path.join(documents.path, 'report.pdf'))
      ..writeAsStringSync('plain');
  });

  tearDown(() async {
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  /// The chat's sealed folder (`UserFileStore`).
  String chatFolder() => path.join(
        support.path,
        'sealed_files',
        'chats',
        UserFileNames.safeChatFolderName(chatName: _chatName, chatId: _chatId),
      );

  /// What a row keeps for a file in the chat folder.
  String stored(String name) => path.join(
        'chats',
        UserFileNames.safeChatFolderName(chatName: _chatName, chatId: _chatId),
        name,
      );

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
  // where files go (security review item 5) — Completer ordering, no clock
  // -----------------------------------------------------------------------
  group('chat folder and file names', () {
    /// Stubs the send with a job that stays running and answers the output
    /// path the cubit chose.
    Future<String> chosenSendPath(
      StreamController<FileProcessingProgress> job,
    ) {
      final chosen = Completer<String>();
      when(
        () => mockService.encryptFileForChat(
          chatId: any(named: 'chatId'),
          inputPath: any(named: 'inputPath'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer((invocation) async {
        chosen.complete(invocation.namedArguments[#outputPath] as String);
        return CryptoCoreSuccess(
          FileProcessingHandler(
            progressStream: job.stream,
            pause: () {},
            resume: () {},
            cancel: () {},
          ),
        );
      });
      return chosen.future;
    }

    test(
        "the chat folder is the app's private sealed_files/chats/<chat> "
        "(<id>), never a folder of the user's own", () async {
      final job = StreamController<FileProcessingProgress>();
      final chosen = chosenSendPath(job);
      final cubit = buildEncrypt()
        ..addFilesToProcess(
          chatId: _chatId,
          chatName: _chatName,
          filePaths: [input.path],
        );

      final outputPath = await chosen;
      expect(
        path.dirname(outputPath),
        path.join(support.path, 'sealed_files', 'chats', 'Bob (6f1e9b2c)'),
      );
      expect(Directory(path.dirname(outputPath)).existsSync(), isTrue);

      await cubit.close();
      await job.close();
    });

    test('a send never replaces an existing .fuzz of the same name', () async {
      Directory(chatFolder()).createSync(recursive: true);
      final earlier = File(path.join(chatFolder(), 'report.pdf.fuzz'))
        ..writeAsStringSync('an earlier send');
      final job = StreamController<FileProcessingProgress>();
      final chosen = chosenSendPath(job);
      final cubit = buildEncrypt()
        ..addFilesToProcess(
          chatId: _chatId,
          chatName: _chatName,
          filePaths: [input.path],
        );

      expect(await chosen, path.join(chatFolder(), 'report (1).pdf.fuzz'));
      expect(earlier.readAsStringSync(), 'an earlier send');

      await cubit.close();
      await job.close();
    });

    test(
        'a receive keeps a copy of the container in the chat folder and '
        'unfuzzes that copy into a private hand-off folder', () async {
      final chosen = Completer<({String input, String output})>();
      final job = StreamController<FileProcessingProgress>();
      when(
        () => mockService.decryptFileForChat(
          chatId: any(named: 'chatId'),
          inputPath: any(named: 'inputPath'),
          outputDirectoryPath: any(named: 'outputDirectoryPath'),
        ),
      ).thenAnswer((invocation) async {
        chosen.complete(
          (
            input: invocation.namedArguments[#inputPath] as String,
            output: invocation.namedArguments[#outputDirectoryPath] as String,
          ),
        );
        return CryptoCoreSuccess(
          CryptoCoreReceivedFile(
            outputPath: path.join(support.path, 'handoff', 'x', 'report.pdf'),
            keptKey: Uint8List(0),
            handler: FileProcessingHandler(
              progressStream: job.stream,
              pause: () {},
              resume: () {},
              cancel: () {},
            ),
          ),
        );
      });
      final container = File(path.join(documents.path, 'report.pdf.fuzz'))
        ..writeAsStringSync('FUZZ....');
      final cubit = buildDecrypt()
        ..addFilesToProcess(
          chatId: _chatId,
          chatName: _chatName,
          filePaths: [container.path],
        );

      final (:input, :output) = await chosen.future;
      expect(input, path.join(chatFolder(), 'report.pdf.fuzz'));
      expect(File(input).readAsStringSync(), 'FUZZ....');
      expect(userFileStore.isHandoff(path.join(output, 'x')), isTrue);
      expect(container.existsSync(), isTrue, reason: "the user's own file");

      await cubit.close();
      await job.close();
    });
  });

  // -----------------------------------------------------------------------
  // encrypt (send)
  // -----------------------------------------------------------------------
  group('FileEncryptionOption', () {
    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      'a new chat folder is kept out of iCloud / Time Machine backups on '
      'Apple platforms (T-0432)',
      setUp: () {
        stubEncrypt(CryptoCoreSuccess(completingHandler()));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(BackupExclusion.channel, (call) async {
          markedForBackupExclusion
              .add((call.arguments as Map)['path'] as String);
          return true;
        });
      },
      tearDown: () => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BackupExclusion.channel, null),
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (_) => expect(
        markedForBackupExclusion,
        Platform.isIOS || Platform.isMacOS ? [chatFolder()] : isEmpty,
      ),
    );

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
            outputFilePath: stored('report.pdf.fuzz'),
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

    blocTest<FileProcessingCubit<FileEncryptionOption>, FileProcessingState>(
      'the row keeps the path relative to the sealed folder, so it survives '
      'an iOS container move',
      setUp: () => stubEncrypt(CryptoCoreSuccess(completingHandler())),
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [input.path],
      ),
      wait: settle,
      verify: (cubit) {
        final row = cubit.state.processedFiles.single.outputFilePath!;
        expect(path.isAbsolute(row), isFalse);
        expect(
          userFileStore.resolve(row),
          path.join(chatFolder(), 'report.pdf.fuzz'),
        );
        expect(cubit.state.processedFiles.single.keptFileKey, isNull);
      },
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
            outputFilePath: stored('20260920-WA0000.jpg.fuzz'),
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

    test(
        'keeps the container and its sealed key, wipes the plain proof copy: '
        'nothing plain is left once the receive completes', () async {
      final keptKey = Uint8List.fromList([0x46, 0x55, 0x5A, 0x5A, 1, 0x20, 7]);
      final handoff = await userFileStore.newHandoffFolder();
      final plain = File(path.join(handoff, 'report.pdf'));
      final job = StreamController<FileProcessingProgress>();
      when(
        () => mockService.decryptFileForChat(
          chatId: any(named: 'chatId'),
          inputPath: any(named: 'inputPath'),
          outputDirectoryPath: any(named: 'outputDirectoryPath'),
        ),
      ).thenAnswer((_) async {
        plain.writeAsStringSync('plain');
        return CryptoCoreSuccess(
          CryptoCoreReceivedFile(
            outputPath: plain.path,
            keptKey: keptKey,
            handler: FileProcessingHandler(
              progressStream: job.stream,
              pause: () {},
              resume: () {},
              cancel: () {},
            ),
          ),
        );
      });
      final cubit = buildDecrypt();
      final finished = cubit.stream.firstWhere(
        (state) =>
            state.processedFiles.isNotEmpty &&
            state.currentProcessingFile == null,
      );
      cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [container.path],
      );
      await untilCalled(
        () => mockService.decryptFileForChat(
          chatId: any(named: 'chatId'),
          inputPath: any(named: 'inputPath'),
          outputDirectoryPath: any(named: 'outputDirectoryPath'),
        ),
      );
      job
        ..add(FileProcessingProgress(progress: 0.5))
        ..add(FileProcessingProgress.completed());

      final state = await finished;
      // Kept under the name sealed inside it, not its outside name
      // (security review 2026-10-26).
      expect(
        state,
        processedAs(
          FileProcessingStatus.completed,
          outputFilePath: stored('report.pdf.fuzz'),
        ),
      );
      expect(state.processedFiles.single.keptFileKey, base64Encode(keptKey));
      expect(
        File(path.join(chatFolder(), 'report.pdf.fuzz')).existsSync(),
        isTrue,
      );
      expect(
        File(path.join(chatFolder(), 'anything.fuzz')).existsSync(),
        isFalse,
      );
      expect(plain.existsSync(), isFalse);
      expect(Directory(handoff).existsSync(), isFalse);

      await cubit.close();
      await job.close();
    });

    test('a spent receive (run failed) leaves no kept container behind',
        () async {
      final job = StreamController<FileProcessingProgress>();
      stubDecrypt(
        CryptoCoreSuccess(
          CryptoCoreReceivedFile(
            outputPath: await userFileStore.newHandoffPath('report.pdf'),
            keptKey: Uint8List(1),
            handler: FileProcessingHandler(
              progressStream: job.stream,
              pause: () {},
              resume: () {},
              cancel: () {},
            ),
          ),
        ),
      );
      final cubit = buildDecrypt();
      final finished = cubit.stream.firstWhere(
        (state) =>
            state.processedFiles.isNotEmpty &&
            state.currentProcessingFile == null,
      );
      cubit.addFilesToProcess(
        chatId: _chatId,
        chatName: _chatName,
        filePaths: [container.path],
      );
      await untilCalled(
        () => mockService.decryptFileForChat(
          chatId: any(named: 'chatId'),
          inputPath: any(named: 'inputPath'),
          outputDirectoryPath: any(named: 'outputDirectoryPath'),
        ),
      );
      job.add(
        FileProcessingProgress.completedWithFailure(
          message: CryptoCoreFailureType.corrupt.name,
          currentProgress: 0.5,
        ),
      );

      await finished;
      expect(Directory(chatFolder()).listSync(), isEmpty);
      expect(container.existsSync(), isTrue, reason: "the user's own file");

      await cubit.close();
      await job.close();
    });

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
        verify: (cubit) {
          expect(
            cubit.state,
            processedAs(FileProcessingStatus.failed, failure: failure),
          );
          // Nothing was spent: the user can try again from their own file.
          expect(Directory(chatFolder()).listSync(), isEmpty);
        },
      );
    }

    blocTest<FileProcessingCubit<FileDecryptionOption>, FileProcessingState>(
      'a run failure after prepare is cannotOpenAskResend (the message is '
      'spent) — errorMessage checked before isComplete',
      setUp: () => stubDecrypt(
        CryptoCoreSuccess(
          CryptoCoreReceivedFile(
            outputPath: path.join(support.path, 'handoff', 'x', 'report.pdf'),
            keptKey: Uint8List(0),
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
            outputPath: path.join(support.path, 'handoff', 'x', 'report.pdf'),
            keptKey: Uint8List(0),
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
