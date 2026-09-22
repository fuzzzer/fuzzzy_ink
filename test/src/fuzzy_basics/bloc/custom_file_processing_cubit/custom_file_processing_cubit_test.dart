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

  /// Time for the fire-and-forget `_processFile` and its stream to settle.
  const settle = Duration(milliseconds: 150);

  setUp(() {
    mockService = MockCryptoCoreService();
    documents =
        Directory.systemTemp.createTempSync('custom_file_processing_cubit_');
    sl.safeRegisterSingleton<AppDocumentsDirectory>(
      AppDocumentsDirectory(directory: documents),
    );
  });

  tearDown(() async {
    await sl.unregister<AppDocumentsDirectory>();
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  String workingFolder() => path.join(documents.path, dummyChatName);

  CustomFileProcessingCubit<FileEncryptionOption> buildEncrypt() =>
      CustomFileProcessingCubit<FileEncryptionOption>(
        cryptoCoreService: mockService,
        processingOption: const FileEncryptionOption(),
      );

  CustomFileProcessingCubit<FileDecryptionOption> buildDecrypt() =>
      CustomFileProcessingCubit<FileDecryptionOption>(
        cryptoCoreService: mockService,
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
      'fuzzes through encryptFileWithPassword into '
      '<Working Folder>/<name>.fuzz with the key text as the password',
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
        final outputPath = path.join(workingFolder(), 'photo.jpg.fuzz');
        verify(
          () => mockService.encryptFileWithPassword(
            password: _password,
            inputPath: '/pick/photo.jpg',
            outputPath: outputPath,
          ),
        ).called(1);
        expect(Directory(workingFolder()).existsSync(), isTrue);
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
    blocTest<CustomFileProcessingCubit<FileDecryptionOption>,
        CustomFileProcessingState>(
      'unfuzzes through decryptFileWithPassword, output = the input name '
      'without .fuzz',
      setUp: () => stubDecrypt(
        CryptoCoreSuccess(_handler([FileProcessingProgress.completed()])),
      ),
      build: buildDecrypt,
      act: (cubit) => cubit.addFilesToProcess(
        filePaths: ['/pick/photo.jpg.fuzz'],
        customKey: _password,
      ),
      wait: settle,
      verify: (cubit) {
        final outputPath = path.join(workingFolder(), 'photo.jpg');
        verify(
          () => mockService.decryptFileWithPassword(
            password: _password,
            inputPath: '/pick/photo.jpg.fuzz',
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
