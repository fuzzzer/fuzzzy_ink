import 'dart:async';
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

  Future<void> _processFile({
    required FileProcessingData fileData,
  }) async {
    try {
      final chatFolderPath = await _ensureChatFolder(
        outputPath: sl.get<AppDocumentsDirectory>().directory.path,
        chatName: fileData.chatName,
      );

      final FileProcessingHandler handler;
      final String outputPath;

      if (processingOption is FileEncryptionOption) {
        outputPath = _fuzzedOutputPath(
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
          _failFile(fileData: fileData, type: _failureTypeOf(res.type));
          return;
        }
        handler = (res as CryptoCoreSuccess<FileProcessingHandler>).data;
      } else if (processingOption is FileDecryptionOption) {
        if (!await _isInputStable(fileData.inputFilePath)) {
          _failFile(
            fileData: fileData,
            type: FileProcessingFailureType.stillArriving,
          );
          return;
        }

        final res = await cryptoCoreService.decryptFileForChat(
          chatId: fileData.chatId,
          inputPath: fileData.inputFilePath,
          outputDirectoryPath: chatFolderPath,
        );
        if (res is CryptoCoreFailure<CryptoCoreReceivedFile>) {
          _failFile(fileData: fileData, type: _failureTypeOf(res.type));
          return;
        }
        final received =
            (res as CryptoCoreSuccess<CryptoCoreReceivedFile>).data;
        handler = received.handler;
        outputPath = received.outputPath;
      } else {
        throw UnimplementedError(
          'Unsupported FileProcessingOption: ${processingOption.runtimeType}',
        );
      }

      _activeFileProcessingHandler = handler;

      _progressSubscription = handler.progressStream.listen(
        (event) => _onProgress(
          event: event,
          fileData: fileData,
          outputPath: outputPath,
        ),
      );

      logger.i('FILE PROCESSING: _progressSubscription set up correctly');
    } catch (error) {
      logger.i('FILE PROCESSING: file processing failed: $error');

      _failFile(fileData: fileData, type: FileProcessingFailureType.unknown);
    }
  }

  Future<bool> _isInputStable(String inputFilePath) async {
    final inputFile = File(inputFilePath);
    final lengthBefore = await inputFile.length();
    await Future<void>.delayed(inputStabilityProbeDuration);
    return await inputFile.length() == lengthBefore;
  }

  void _onProgress({
    required FileProcessingProgress event,
    required FileProcessingData fileData,
    required String outputPath,
  }) {
    if (event.isCancelled) {
      _resetThrottle();
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
      _failFile(
        fileData: fileData,
        type: _runFailureType(),
        progress: event.progress,
      );
      return;
    }

    if (event.isComplete) {
      _resetThrottle();
      _finishFile(fileData: fileData, outputPath: outputPath);
      return;
    }

    _handleThrottledProgress(
      fileData: fileData,
      progress: event.progress,
    );
  }

  /// The finished file goes where the user can find it before the row is
  /// written (T-0366); the bar stays full while it moves. A place that
  /// cannot be written keeps the app's own copy, which still opens and
  /// shares.
  Future<void> _finishFile({
    required FileProcessingData fileData,
    required String outputPath,
  }) async {
    _updateFileStatus(
      fileData: fileData,
      newStatus: FileProcessingStatus.inProgress,
      newProgress: 1,
    );

    String publishedPath;
    try {
      publishedPath = await userFileStore.publish(
        outputPath: outputPath,
        chatName: fileData.chatName,
      );
    } catch (error) {
      logger.w('FILE PROCESSING: could not publish $outputPath: $error');
      publishedPath = outputPath;
    }

    _markFileAsFinished(
      fileData: fileData,
      status: FileProcessingStatus.completed,
      outputFilePath: publishedPath,
      progress: 1,
    );
    _goToNextFileProcessing();
    logger.i('FILE PROCESSING: Marked as isComplete $state');
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

  void _failFile({
    required FileProcessingData fileData,
    required FileProcessingFailureType type,
    double? progress,
  }) {
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
    double? progress,
    FileProcessingFailure? failure,
  }) {
    final updatedFile = fileData.copyWith(
      status: status,
      outputFilePath: outputFilePath,
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

Future<String> _ensureChatFolder({
  required String outputPath,
  required String chatName,
}) async {
  final chatIdFolder = Directory(path.join(outputPath, chatName));

  if (!await chatIdFolder.exists()) {
    await chatIdFolder.create(recursive: true);
  }

  return chatIdFolder.path;
}

String _fuzzedOutputPath({
  required String chatFolderPath,
  required String inputFilePath,
  required String fuzzedFileIdentificator,
}) {
  final fileName =
      UserFileLocation.cleanPickedFileName(path.basename(inputFilePath));
  return path.join(chatFolderPath, '$fileName.$fuzzedFileIdentificator');
}
