import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:path/path.dart' as path;

export 'components/components.dart';

// ignore_for_file: avoid_redundant_argument_values

part 'file_processing_state.dart';

class FileProcessingCubit<ActualProcessingOption extends FileProcessingOption>
    extends Cubit<FileProcessingState> {
  final CryptoCoreService cryptoCoreService;
  final UserFileStore userFileStore;
  final ActualProcessingOption processingOption;

  FileProcessingCubit({
    required this.cryptoCoreService,
    required this.userFileStore,
    required this.processingOption,
  }) : super(const FileProcessingState());

  StreamSubscription<FileProcessingProgress>? _progressSubscription;
  FileProcessingHandler? _activeFileProcessingHandler;

  static const progressPostingThrottleDuration = Duration(milliseconds: 100);
  Timer? _throttleTimer;
  double? _pendingProgress;

  /// Two size samples this far apart must agree before a container is
  /// received: `decryptFileForChat` consumes the container's key message, so
  /// a file that is still being written (a download, a cloud sync) would be
  /// spent for good.
  static const inputStabilityProbeDuration = Duration(milliseconds: 500);

  void markProcessedFilesAsReadAndClear({
    required List<FileProcessingData> readProcessedFiles,
  }) {
    final updatedProcessedFilesList = state.processedFiles
        .where(
          (processedFile) => !readProcessedFiles.contains(processedFile),
        )
        .toList();

    emit(
      state.copyWith(
        processedFiles: updatedProcessedFilesList,
      ),
    );
  }

  void addFilesToProcess({
    required String chatId,
    required String chatName,
    required List<String> filePaths,
  }) {
    final now = DateTime.now();

    final newFilesToBeProcessed = filePaths.map(
      (path) => FileProcessingData(
        chatId: chatId,
        chatName: chatName,
        inputFilePath: path,
        encryptionStartTime: now,
        status: FileProcessingStatus.pending,
      ),
    );

    final updatedQueue = [
      ...state.toBeProcessedFiles,
      ...newFilesToBeProcessed,
    ];

    emit(state.copyWith(toBeProcessedFiles: updatedQueue));

    if (state.currentProcessingFile == null) {
      _startNextFileProcessing();
    }
  }

  void _startNextFileProcessing() {
    final toBeProcessedFiles = state.toBeProcessedFiles;

    if (toBeProcessedFiles.isEmpty) {
      emit(state.copyWithCleanProgress());
      return;
    }

    logger.i('FILE PROCESSING: To be processed files: $toBeProcessedFiles');

    final nextFileData = toBeProcessedFiles.first.copyWith(
      status: FileProcessingStatus.inProgress,
      progress: 0,
    );

    final updatedToBeProcessedFiles = [
      nextFileData,
      ...toBeProcessedFiles.skip(1),
    ];

    emit(
      state.copyWith(
        toBeProcessedFiles: updatedToBeProcessedFiles,
        currentProcessingFile: nextFileData,
        progress: 0,
      ),
    );

    _processFile(fileData: nextFileData);
  }

  /// A send streams the picked file into `<name>.fuzz` in the chat's sealed
  /// folder. A receive first copies the container into that folder — the
  /// copy is what the app keeps — then unfuzzes it once into a hand-off
  /// folder to prove every chunk opens, and wipes that plain copy at once:
  /// the row keeps the container and its sealed key (`PROTOCOL.md` §9.6),
  /// and "Open" unfuzzes it again when asked.
  Future<void> _processFile({
    required FileProcessingData fileData,
  }) async {
    String? keptContainerPath;
    try {
      final chatFolderPath = await userFileStore.chatFolder(
        chatName: fileData.chatName,
        chatId: fileData.chatId,
      );

      final FileProcessingHandler handler;
      final _Job job;

      if (processingOption is FileEncryptionOption) {
        final outputPath = await _fuzzedOutputPath(
          chatFolderPath: chatFolderPath,
          inputFilePath: fileData.inputFilePath,
          fuzzedFileIdentificator: fuzzedFileIdentificator,
        );

        final res = await cryptoCoreService.encryptFileForChat(
          chatId: fileData.chatId,
          inputPath: fileData.inputFilePath,
          outputPath: outputPath,
        );
        if (res is CryptoCoreFailure<FileProcessingHandler>) {
          await _failFile(fileData: fileData, type: _failureTypeOf(res.type));
          return;
        }
        handler = (res as CryptoCoreSuccess<FileProcessingHandler>).data;
        job = (keptPath: outputPath, plainPath: null, keptFileKey: null);
      } else if (processingOption is FileDecryptionOption) {
        if (!await _isInputStable(fileData.inputFilePath)) {
          await _failFile(
            fileData: fileData,
            type: FileProcessingFailureType.stillArriving,
          );
          return;
        }

        keptContainerPath = await UserFileNames.uniqueOutputPath(
          path.join(
            chatFolderPath,
            UserFileNames.cleanPickedFileName(
              path.basename(fileData.inputFilePath),
            ),
          ),
        );
        await File(fileData.inputFilePath).copy(keptContainerPath);

        final res = await cryptoCoreService.decryptFileForChat(
          chatId: fileData.chatId,
          inputPath: keptContainerPath,
          outputDirectoryPath: await userFileStore.newHandoffFolder(),
        );
        if (res is CryptoCoreFailure<CryptoCoreReceivedFile>) {
          await _deleteKeptContainer(keptContainerPath);
          await _failFile(fileData: fileData, type: _failureTypeOf(res.type));
          return;
        }
        final received =
            (res as CryptoCoreSuccess<CryptoCoreReceivedFile>).data;
        handler = received.handler;
        job = (
          keptPath: keptContainerPath,
          plainPath: received.outputPath,
          keptFileKey: base64Encode(received.keptKey),
        );
      } else {
        throw UnimplementedError(
          'Unsupported FileProcessingOption: ${processingOption.runtimeType}',
        );
      }

      _activeFileProcessingHandler = handler;

      _progressSubscription = handler.progressStream.listen(
        (event) => _onProgress(event: event, fileData: fileData, job: job),
      );

      logger.i('FILE PROCESSING: _progressSubscription set up correctly');
    } catch (error) {
      logger.i('FILE PROCESSING: file processing failed: $error');

      if (keptContainerPath != null) {
        await _deleteKeptContainer(keptContainerPath);
      }
      await _failFile(
        fileData: fileData,
        type: FileProcessingFailureType.unknown,
      );
    }
  }

  Future<bool> _isInputStable(String inputFilePath) async {
    final inputFile = File(inputFilePath);
    final lengthBefore = await inputFile.length();
    await Future<void>.delayed(inputStabilityProbeDuration);
    return await inputFile.length() == lengthBefore;
  }

  Future<void> _onProgress({
    required FileProcessingProgress event,
    required FileProcessingData fileData,
    required _Job job,
  }) async {
    if (event.isCancelled) {
      _resetThrottle();
      await _dropJobFiles(job);
      await userFileStore.discardPickedCopy(fileData.inputFilePath);
      _markFileAsFinished(
        fileData: fileData,
        status: FileProcessingStatus.canceled,
        outputFilePath: null,
        progress: event.progress,
        failure: _cancelFailure(),
      );
      _goToNextFileProcessing();
      logger.i('FILE PROCESSING: Marked as isCancelled $state');
      return;
    }

    // A failure is terminal with isComplete set too — it must win.
    if (event.errorMessage != null) {
      _resetThrottle();
      logger.i('FILE PROCESSING: run failed: ${event.errorMessage}');
      await _dropJobFiles(job);
      await _failFile(
        fileData: fileData,
        type: _runFailureType(),
        progress: event.progress,
      );
      return;
    }

    if (event.isComplete) {
      _resetThrottle();
      await _finishFile(fileData: fileData, job: job);
      return;
    }

    _handleThrottledProgress(
      fileData: fileData,
      progress: event.progress,
    );
  }

  /// The plain proof copy of a receive is wiped before the row is written;
  /// the row keeps the sealed file only.
  Future<void> _finishFile({
    required FileProcessingData fileData,
    required _Job job,
  }) async {
    _updateFileStatus(
      fileData: fileData,
      newStatus: FileProcessingStatus.inProgress,
      newProgress: 1,
    );

    final plainPath = job.plainPath;
    var keptPath = job.keptPath;
    if (plainPath != null) {
      keptPath = await _nameKeptByInnerName(keptPath, plainPath);
      await userFileStore.wipe(plainPath);
    }
    await userFileStore.discardPickedCopy(fileData.inputFilePath);

    _markFileAsFinished(
      fileData: fileData,
      status: FileProcessingStatus.completed,
      outputFilePath: userFileStore.storedPathOf(keptPath),
      keptFileKey: job.keptFileKey,
      progress: 1,
    );
    _goToNextFileProcessing();
    logger.i('FILE PROCESSING: Marked as isComplete $state');
  }

  /// A kept received container is named after the name its sender sealed
  /// inside it — checked and made safe by the core, the name the opened
  /// copy got — not after its outside file name, which anyone on the way
  /// could have changed (`notes.txt.fuzz` renamed `notes.bat.fuzz`).
  /// Security review 2026-10-26. A rename that fails keeps the old name.
  Future<String> _nameKeptByInnerName(String keptPath, String plainPath) async {
    final desired = path.join(
      path.dirname(keptPath),
      '${path.basename(plainPath)}.$fuzzedFileIdentificator',
    );
    if (path.equals(desired, keptPath)) return keptPath;
    try {
      final target = await UserFileNames.uniqueOutputPath(desired);
      return (await File(keptPath).rename(target)).path;
    } on FileSystemException catch (error) {
      logger.w('FILE PROCESSING: kept container keeps its name: $error');
      return keptPath;
    }
  }

  /// A failed or cancelled run: the core already removed its `.part`; the
  /// hand-off folder goes, and so does a received container — its message is
  /// spent, so it can never be opened.
  Future<void> _dropJobFiles(_Job job) async {
    final plainPath = job.plainPath;
    if (plainPath != null) {
      await userFileStore.wipe(plainPath);
      await _deleteKeptContainer(job.keptPath);
    }
  }

  Future<void> _deleteKeptContainer(String keptContainerPath) async {
    try {
      final kept = File(keptContainerPath);
      if (await kept.exists()) await kept.delete();
    } catch (error) {
      logger.w('FILE PROCESSING: could not delete $keptContainerPath: $error');
    }
  }

  /// A run that fails after `decryptFileForChat` succeeded has already spent
  /// the container's key message: the file cannot be opened on this device
  /// again, the sender has to send it again. A failed send spends nothing.
  FileProcessingFailureType _runFailureType() {
    return processingOption is FileDecryptionOption
        ? FileProcessingFailureType.cannotOpenAskResend
        : FileProcessingFailureType.unknown;
  }

  /// Same for a cancelled receive — the row keeps its `canceled` status and
  /// carries the hint that the container is spent. A cancelled send has none.
  FileProcessingFailure? _cancelFailure() {
    return processingOption is FileDecryptionOption
        ? FileProcessingFailure(type: FileProcessingFailureType.cancelled)
        : null;
  }

  Future<void> _failFile({
    required FileProcessingData fileData,
    required FileProcessingFailureType type,
    double? progress,
  }) async {
    await userFileStore.discardPickedCopy(fileData.inputFilePath);
    _markFileAsFinished(
      fileData: fileData,
      status: FileProcessingStatus.failed,
      outputFilePath: null,
      progress: progress,
      failure: FileProcessingFailure(type: type),
    );
    _goToNextFileProcessing();
  }

  static FileProcessingFailureType _failureTypeOf(CryptoCoreFailureType type) {
    return switch (type) {
      CryptoCoreFailureType.replay => FileProcessingFailureType.alreadyUnfuzzed,
      CryptoCoreFailureType.wrongChat => FileProcessingFailureType.wrongChat,
      CryptoCoreFailureType.tooOld => FileProcessingFailureType.tooOld,
      CryptoCoreFailureType.newerVersion => FileProcessingFailureType.newerApp,
      CryptoCoreFailureType.corrupt ||
      CryptoCoreFailureType.unsupportedFormat =>
        FileProcessingFailureType.corrupt,
      _ => FileProcessingFailureType.unknown,
    };
  }

  void _resetThrottle() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _pendingProgress = null;
  }

  void _handleThrottledProgress({
    required FileProcessingData fileData,
    required double progress,
  }) {
    if (_throttleTimer != null) {
      _pendingProgress = progress;
      return;
    }

    _updateFileStatus(
      fileData: fileData,
      newStatus: FileProcessingStatus.inProgress,
      newProgress: progress,
    );

    //Timer callback will collect all acumulated _pendingProgress which was saved while progress was being detected when timer was ON.
    _throttleTimer = Timer(progressPostingThrottleDuration, () {
      if (_pendingProgress != null) {
        _updateFileStatus(
          fileData: fileData,
          newStatus: FileProcessingStatus.inProgress,
          newProgress: _pendingProgress!,
        );
        _pendingProgress = null;
      }
      _throttleTimer = null;
    });
  }

  void _markFileAsFinished({
    required FileProcessingData fileData,
    required FileProcessingStatus status,
    required String? outputFilePath,
    String? keptFileKey,
    double? progress,
    FileProcessingFailure? failure,
  }) {
    final updatedFile = fileData.copyWith(
      status: status,
      outputFilePath: outputFilePath,
      keptFileKey: keptFileKey,
      progress: progress ?? fileData.progress,
      isProcessed: true,
      failure: failure,
    );

    final updatedState =
        _removeFromQueueAndAddToProcessed(fileProcessingData: updatedFile);

    final isActive =
        updatedFile.inputFilePath == state.currentProcessingFile?.inputFilePath;

    emit(
      updatedState.copyWith(
        currentProcessingFile: isActive ? null : state.currentProcessingFile,
        progress: isActive ? 0.0 : state.progress,
      ),
    );
  }

  FileProcessingState _removeFromQueueAndAddToProcessed({
    required FileProcessingData fileProcessingData,
  }) {
    final newToBeProcessed = state.toBeProcessedFiles
        .where((e) => e.inputFilePath != fileProcessingData.inputFilePath)
        .toList();
    final newProcessed = [...state.processedFiles, fileProcessingData];

    return state.copyWith(
      toBeProcessedFiles: newToBeProcessed,
      processedFiles: newProcessed,
    );
  }

  void _goToNextFileProcessing() {
    _cleanCurrentFileProcessingResources();
    _startNextFileProcessing();
  }

  void _cleanCurrentFileProcessingResources() {
    _progressSubscription?.cancel();
    _progressSubscription = null;
    _activeFileProcessingHandler = null;
  }

  void _updateFileStatus({
    required FileProcessingData fileData,
    required FileProcessingStatus newStatus,
    required double newProgress,
  }) {
    final updatedToBeProcessedFiles = state.toBeProcessedFiles.map((item) {
      if (item.inputFilePath == fileData.inputFilePath) {
        return item.copyWith(
          status: newStatus,
          progress: newProgress,
        );
      }
      return item;
    }).toList();

    final isActive =
        fileData.inputFilePath == state.currentProcessingFile?.inputFilePath;

    emit(
      state.copyWith(
        toBeProcessedFiles: updatedToBeProcessedFiles,
        progress: isActive ? newProgress : state.progress,
      ),
    );
  }

  void pauseFile() => _activeFileProcessingHandler?.pause();

  void resumeFile() => _activeFileProcessingHandler?.resume();

  void cancelFile() => _activeFileProcessingHandler?.cancel();

  @override
  Future<void> close() {
    _progressSubscription?.cancel();
    _activeFileProcessingHandler = null;
    return super.close();
  }
}

/// `<name>.fuzz` in the chat's folder, or `<name> (1).fuzz`, … when taken:
/// a send never replaces an existing file.
Future<String> _fuzzedOutputPath({
  required String chatFolderPath,
  required String inputFilePath,
  required String fuzzedFileIdentificator,
}) {
  final fileName =
      UserFileNames.cleanPickedFileName(path.basename(inputFilePath));
  return UserFileNames.uniqueOutputPath(
    path.join(chatFolderPath, '$fileName.$fuzzedFileIdentificator'),
  );
}

/// What a running job leaves: the sealed file the row will keep (the sent
/// container, or the received one), and for a receive the plain proof copy
/// in its hand-off folder and the container's sealed key.
typedef _Job = ({String keptPath, String? plainPath, String? keptFileKey});
