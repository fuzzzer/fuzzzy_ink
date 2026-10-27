part of 'chat_file_cubit.dart';

class ChatFileState {
  final StateStatus status;

  /// 0..1 while a received file is unfuzzed.
  final double progress;
  final FileProcessingFailure? failure;

  const ChatFileState({
    this.status = StateStatus.initial,
    this.progress = 0,
    this.failure,
  });

  ChatFileState copyWith({
    StateStatus? status,
    double? progress,
    FileProcessingFailure? failure,
  }) {
    return ChatFileState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() =>
      'ChatFileState(status: $status, progress: $progress, failure: ${failure?.type})';
}
