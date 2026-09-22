import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:path/path.dart' as path;

// ignore_for_file: avoid_redundant_argument_values

part 'custom_file_processing_state.dart';

class CustomFileProcessingCubit<
        ActualProcessingOption extends FileProcessingOption>
    extends Cubit<CustomFileProcessingState> {
  final CryptoCoreService cryptoCoreService;
  final ActualProcessingOption processingOption;

  CustomFileProcessingCubit({
    required this.cryptoCoreService,
    required this.processingOption,
  }) : super(const CustomFileProcessingState());

  StreamSubscription<FileProcessingProgress>? _progressSubscription;
  FileProcessingHandler? _activeFileProcessingHandler;

  static const progressPostingThrottleDuration = Duration(milliseconds: 100);
  Timer? _throttleTimer;
  double? _pendingProgress;

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
    required List<String> filePaths,
    required String customKey,
  }) {
    final now = DateTime.now();

    final newFilesToBeProcessed = filePaths.map(
      (path) => FileProcessingData(
        chatId: dummyChatId,
        chatName: dummyChatName,
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
      _startNextFileProcessing(
        customKey: customKey,
      );
    }
  }

  void _startNextFileProcessing({
    required String customKey,
  }) {
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

    _processFile(
      fileData: nextFileData,
      customKey: customKey,
    );
  }

  Future<void> _processFile({
    required FileProcessingData fileData,
    required String customKey,
  }) async {
    try {
      String generalOutputPath = sl.get<AppDocumentsDirectory>().directory.path;

      final CryptoCoreResponse<FileProcessingHandler> res;

      if (processingOption is FileEncryptionOption) {
        generalOutputPath = await _buildOutputPathInChatFolder(
          inputFilePath: fileData.inputFilePath,
          outputPath: generalOutputPath,
          chatName: fileData.chatName,
          isEncryption: true,
          fuzzedFileIdentificator: fuzzedFileIdentificator,
        );

        res = await cryptoCoreService.encryptFileWithPassword(
          password: customKey,
          inputPath: fileData.inputFilePath,
          outputPath: generalOutputPath,
        );
      } else if (processingOption is FileDecryptionOption) {
        generalOutputPath = await _buildOutputPathInChatFolder(
          inputFilePath: fileData.inputFilePath,
          outputPath: generalOutputPath,
          chatName: fileData.chatName,
          isEncryption: false,
          fuzzedFileIdentificator: fuzzedFileIdentificator,
        );

        res = await cryptoCoreService.decryptFileWithPassword(
          password: customKey,
          inputPath: fileData.inputFilePath,
          outputPath: generalOutputPath,
        );
      } else {
        throw UnimplementedError(
          'Unsupported FileProcessingOption: ${processingOption.runtimeType}',
        );
      }

      if (res is CryptoCoreFailure<FileProcessingHandler>) {
        _failFile(
          fileData: fileData,
          type: FileProcessingFailureType.unknown,
          customKey: customKey,
        );
        return;
      }
      final handler = (res as CryptoCoreSuccess<FileProcessingHandler>).data;

      _activeFileProcessingHandler = handler;

      _progressSubscription = handler.progressStream.listen(
        (event) => _onProgress(
          event: event,
          fileData: fileData,
          outputPath: generalOutputPath,
          customKey: customKey,
        ),
      );

      logger.i('FILE PROCESSING: _progressSubscription set up correctly');
    } catch (error) {
      logger.i('FILE PROCESSING: file processing failed: $error');

      _failFile(
        fileData: fileData,
        type: FileProcessingFailureType.unknown,
        customKey: customKey,
      );
    }
  }

  void _onProgress({
    required FileProcessingProgress event,
    required FileProcessingData fileData,
    required String outputPath,
    required String customKey,
  }) {
    if (event.isCancelled) {
      _resetThrottle();
      _markFileAsFinished(
        fileData: fileData,
        status: FileProcessingStatus.canceled,
        outputFilePath: null,
        progress: event.progress,
      );
      _goToNextFileProcessing(
        customKey: customKey,
      );
      logger.i('FILE PROCESSING: Marked as isCancelled $state');
      return;
    }

    // A failure is terminal with isComplete set too — it must win.
    if (event.errorMessage != null) {
      _resetThrottle();
      logger.i('FILE PROCESSING: run failed: ${event.errorMessage}');
      _failFile(
        fileData: fileData,
        type: _runFailureTypeOf(event.errorMessage!),
        customKey: customKey,
        progress: event.progress,
      );
      return;
    }

    if (event.isComplete) {
      _resetThrottle();
      _markFileAsFinished(
        fileData: fileData,
        status: FileProcessingStatus.completed,
        outputFilePath: outputPath,
        progress: 1,
      );
      _goToNextFileProcessing(
        customKey: customKey,
      );
      logger.i('FILE PROCESSING: Marked as isComplete $state');
      return;
    }

    _handleThrottledProgress(
      fileData: fileData,
      progress: event.progress,
    );
  }

  void _failFile({
    required FileProcessingData fileData,
    required FileProcessingFailureType type,
    required String customKey,
    double? progress,
  }) {
    _markFileAsFinished(
      fileData: fileData,
      status: FileProcessingStatus.failed,
      outputFilePath: null,
      progress: progress,
      failure: FileProcessingFailure(type: type),
    );
    _goToNextFileProcessing(
      customKey: customKey,
    );
  }

  /// The terminal event's `errorMessage` is a [CryptoCoreFailureType] name.
  static FileProcessingFailureType _runFailureTypeOf(String errorMessage) {
    return switch (CryptoCoreFailureType.values.asNameMap()[errorMessage]) {
      CryptoCoreFailureType.wrongPassword =>
        FileProcessingFailureType.wrongPassword,
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

  CustomFileProcessingState _removeFromQueueAndAddToProcessed({
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

  void _goToNextFileProcessing({
    required String customKey,
  }) {
    _cleanCurrentFileProcessingResources();
    _startNextFileProcessing(customKey: customKey);
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

Future<String> _buildOutputPathInChatFolder({
  required String inputFilePath,
  required String outputPath,
  required String chatName,
  required bool isEncryption,
  required String fuzzedFileIdentificator,
}) async {
  final chatIdFolder = Directory(path.join(outputPath, chatName));

  if (!await chatIdFolder.exists()) {
    await chatIdFolder.create(recursive: true);
  }

  final fileName = path.basename(inputFilePath);
  if (isEncryption) {
    return path.join(chatIdFolder.path, '$fileName.$fuzzedFileIdentificator');
  } else {
    final defuzzedFileName = fileName.endsWith('.$fuzzedFileIdentificator')
        ? fileName.substring(
            0,
            fileName.length - '.$fuzzedFileIdentificator'.length,
          )
        : fileName;
    return path.join(chatIdFolder.path, defuzzedFileName);
  }
}
