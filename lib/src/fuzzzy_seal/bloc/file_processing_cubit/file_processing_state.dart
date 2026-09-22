part of 'file_processing_cubit.dart';

class FileProcessingState {
  final double progress; // value between 0 and 1
  final FileProcessingData? currentProcessingFile;
  final List<FileProcessingData> toBeProcessedFiles;
  final List<FileProcessingData> processedFiles;

  List<FileProcessingData> getToBeProcessedFilesByChatId(String chatId) {
    return toBeProcessedFiles.where((tbpf) => tbpf.chatId == chatId).toList();
  }

  List<FileProcessingData> getProcessedFilesByChatId(String chatId) {
    return processedFiles.where((pf) => pf.chatId == chatId).toList();
  }

  const FileProcessingState({
    this.progress = 0.0,
    this.currentProcessingFile,
    this.toBeProcessedFiles = const [],
    this.processedFiles = const [],
  });

  FileProcessingState copyWith({
    double? progress,
    FileProcessingData? currentProcessingFile,
    List<FileProcessingData>? toBeProcessedFiles,
    List<FileProcessingData>? processedFiles,
  }) {
    return FileProcessingState(
      progress: progress ?? this.progress,
      currentProcessingFile:
          currentProcessingFile ?? this.currentProcessingFile,
      toBeProcessedFiles: toBeProcessedFiles ?? this.toBeProcessedFiles,
      processedFiles: processedFiles ?? this.processedFiles,
    );
  }

  FileProcessingState copyWithCleanProgress() {
    return FileProcessingState(
      toBeProcessedFiles: toBeProcessedFiles,
      processedFiles: processedFiles,
    );
  }

  @override
  String toString() {
    return 'FileProcessingState(progress: $progress, currentProcessingFile: $currentProcessingFile, toBeProcessedFiles: $toBeProcessedFiles, processedFiles: $processedFiles)';
  }
}
