import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

const _password = 'correct horse';

FileProcessingHandler _handler(List<FileProcessingProgress> events) =>
    FileProcessingHandler(
      progressStream: Stream.fromIterable(events),
      pause: () {},
      resume: () {},
      cancel: () {},
    );

void main() {
  late MockCryptoCoreService mockService;
  late Directory documents;
  late UserFileStore store;

  /// Time for the fire-and-forget `_processFile` and its stream to settle.
  const settle = Duration(milliseconds: 150);

  setUp(() {
    mockService = MockCryptoCoreService();
    documents =
        Directory.systemTemp.createTempSync('custom_file_processing_cubit_');
    store = UserFileStore(
      supportDirectoryPath: path.join(documents.path, 'support'),
      temporaryDirectoryPath: path.join(documents.path, 'tmp'),
      documentsDirectoryPath: documents.path,
    );
  });

  tearDown(() async {
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  /// Where Basics keeps its password containers.
  String basicsFolder() =>
      path.join(documents.path, 'support', 'sealed_files', 'basics');

  CustomFileProcessingCubit<FileEncryptionOption> buildEncrypt() =>
      CustomFileProcessingCubit<FileEncryptionOption>(
        cryptoCoreService: mockService,
        userFileStore: store,
        processingOption: const FileEncryptionOption(),
      );

  CustomFileProcessingCubit<FileDecryptionOption> buildDecrypt() =>
      CustomFileProcessingCubit<FileDecryptionOption>(
        cryptoCoreService: mockService,
        userFileStore: store,
        processingOption: const FileDecryptionOption(),
      );

  void stubEncrypt(CryptoCoreResponse<FileProcessingHandler> response) {
    when(
      () => mockService.encryptFileWithPassword(
        password: any(named: 'password'),
        inputPath: any(named: 'inputPath'),
        outputPath: any(named: 'outputPath'),
      ),
    ).thenAnswer((_) async => response);
  }

  void stubDecrypt(CryptoCoreResponse<FileProcessingHandler> response) {
    when(
      () => mockService.decryptFileWithPassword(
        password: any(named: 'password'),
        inputPath: any(named: 'inputPath'),
        outputPath: any(named: 'outputPath'),
      ),
    ).thenAnswer((_) async => response);
  }

  /// The one processed file of the final state.
  Matcher processedAs(
    FileProcessingStatus status, {
    String? outputFilePath,
    FileProcessingFailureType? failure,
  }) =>
      isA<CustomFileProcessingState>()
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
          );

  group('FileEncryptionOption', () {
    blocTest<CustomFileProcessingCubit<FileEncryptionOption>,
        CustomFileProcessingState>(
      "fuzzes through encryptFileWithPassword into the app's Basics folder "
      'as <name>.fuzz with the key text as the password',
      setUp: () => stubEncrypt(
        CryptoCoreSuccess(
          _handler([
            FileProcessingProgress(progress: 0.5),
            FileProcessingProgress.completed(),
          ]),
        ),
      ),
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        filePaths: ['/pick/photo.jpg'],
        customKey: _password,
      ),
      wait: settle,
      verify: (cubit) {
        final outputPath = path.join(basicsFolder(), 'photo.jpg.fuzz');
        verify(
          () => mockService.encryptFileWithPassword(
            password: _password,
            inputPath: '/pick/photo.jpg',
            outputPath: outputPath,
          ),
        ).called(1);
        expect(Directory(basicsFolder()).existsSync(), isTrue);
        expect(
          Directory(path.join(documents.path, 'Working Folder')).existsSync(),
          isFalse,
        );
        expect(
          cubit.state,
          processedAs(
            FileProcessingStatus.completed,
            outputFilePath: outputPath,
          ),
        );
      },
    );

    blocTest<CustomFileProcessingCubit<FileEncryptionOption>,
        CustomFileProcessingState>(
      'a service failure is failed/unknown',
      setUp: () => stubEncrypt(
        const CryptoCoreFailure(CryptoCoreFailureType.internal),
      ),
      build: buildEncrypt,
      act: (cubit) => cubit.addFilesToProcess(
        filePaths: ['/pick/photo.jpg'],
        customKey: _password,
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
  });

  group('FileDecryptionOption', () {
    /// Runs one decryption of `photo.jpg.fuzz` to completion (Completer
    /// ordering, no wall clock) and answers the cubit and the plain copy.
    Future<(CustomFileProcessingCubit<FileDecryptionOption>, String)>
        decryptOnce() async {
      final chosen = Completer<String>();
      final progress = StreamController<FileProcessingProgress>();
      addTearDown(progress.close);
      when(
        () => mockService.decryptFileWithPassword(
          password: any(named: 'password'),
          inputPath: any(named: 'inputPath'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer((invocation) async {
        final outputPath = invocation.namedArguments[#outputPath] as String;
        File(outputPath).writeAsStringSync('plain');
        chosen.complete(outputPath);
        return CryptoCoreSuccess(
          FileProcessingHandler(
            progressStream: progress.stream,
            pause: () {},
            resume: () {},
            cancel: () {},
          ),
        );
      });
      final cubit = buildDecrypt();
      final done = cubit.stream.firstWhere(
        (state) =>
            state.processedFiles.length == 1 &&
            state.currentProcessingFile == null,
      );
      cubit.addFilesToProcess(
        filePaths: ['/pick/photo.jpg.fuzz'],
        customKey: _password,
      );
      final copy = await chosen.future;
      progress.add(FileProcessingProgress.completed());
      await done;
      return (cubit, copy);
    }

    test(
        'unfuzzes into a private hand-off copy named without .fuzz, never '
        'into a user folder', () async {
      final (cubit, copy) = await decryptOnce();

      expect(path.basename(copy), 'photo.jpg');
      expect(store.isHandoff(copy), isTrue);
      expect(cubit.state.processedFiles.single.outputFilePath, copy);
      expect(File(copy).existsSync(), isTrue);
      expect(
        Directory(path.join(documents.path, 'Working Folder')).existsSync(),
        isFalse,
      );
      await cubit.close();
    });

    test('a saved copy is wiped at once and its entry loses the path',
        () async {
      final (cubit, copy) = await decryptOnce();

      await cubit.wipePlainCopy(copy);

      expect(File(copy).existsSync(), isFalse);
      expect(cubit.state.processedFiles.single.outputFilePath, isNull);
      await cubit.close();
    });

    test('every copy still held is wiped when the page closes', () async {
      final (cubit, copy) = await decryptOnce();

      await cubit.close();

      expect(File(copy).existsSync(), isFalse);
      expect(Directory(store.handoffRootPath).listSync(), isEmpty);
    });

    for (final (text, failure) in [
      (
        CryptoCoreFailureType.wrongPassword,
        FileProcessingFailureType.wrongPassword
      ),
      (CryptoCoreFailureType.corrupt, FileProcessingFailureType.corrupt),
      (
        CryptoCoreFailureType.unsupportedFormat,
        FileProcessingFailureType.corrupt
      ),
      (CryptoCoreFailureType.io, FileProcessingFailureType.unknown),
    ]) {
      blocTest<CustomFileProcessingCubit<FileDecryptionOption>,
          CustomFileProcessingState>(
        'a failure event (isComplete + errorMessage ${text.name}) is failed/'
        '${failure.name}, never completed',
        setUp: () => stubDecrypt(
          CryptoCoreSuccess(
            _handler([
              FileProcessingProgress(progress: 0.5),
              FileProcessingProgress.completedWithFailure(
                message: text.name,
                currentProgress: 0.5,
              ),
            ]),
          ),
        ),
        build: buildDecrypt,
        act: (cubit) => cubit.addFilesToProcess(
          filePaths: ['/pick/photo.jpg.fuzz'],
          customKey: _password,
        ),
        wait: settle,
        verify: (cubit) => expect(
          cubit.state,
          processedAs(FileProcessingStatus.failed, failure: failure),
        ),
      );
    }

    blocTest<CustomFileProcessingCubit<FileDecryptionOption>,
        CustomFileProcessingState>(
      'a cancel event is canceled with no output path',
      setUp: () => stubDecrypt(
        CryptoCoreSuccess(
          _handler([
            FileProcessingProgress(progress: 0.25),
            FileProcessingProgress.cancelled(),
          ]),
        ),
      ),
      build: buildDecrypt,
      act: (cubit) => cubit.addFilesToProcess(
        filePaths: ['/pick/photo.jpg.fuzz'],
        customKey: _password,
      ),
      wait: settle,
      verify: (cubit) => expect(
        cubit.state,
        processedAs(FileProcessingStatus.canceled),
      ),
    );
  });
}
