part of 'chat_file_injector_cubit.dart';

class ChatFileInjectorState {
  final StateStatus status;
  final List<FileProcessingData>? failedToAddProcessedFiles;

  const ChatFileInjectorState({
    required this.status,
    this.failedToAddProcessedFiles,
  });

  ChatFileInjectorState copyWith({
    StateStatus? status,
    List<FileProcessingData>? failedToAddProcessedFiles,
  }) {
    return ChatFileInjectorState(
      status: status ?? this.status,
      failedToAddProcessedFiles:
          failedToAddProcessedFiles ?? this.failedToAddProcessedFiles,
    );
  }

  @override
  String toString() {
    return 'ConnectedChatState(status: $status, failedToAddProcessedFiles: $failedToAddProcessedFiles)';
  }
}
