part of 'chat_archive_export_cubit.dart';

class ChatArchiveExportState {
  const ChatArchiveExportState({
    this.status = StateStatus.initial,
    this.failureType,
  });

  final StateStatus status;
  final ChatArchiveExportFailureType? failureType;

  ChatArchiveExportState copyWith({
    StateStatus? status,
    ChatArchiveExportFailureType? failureType,
  }) {
    return ChatArchiveExportState(
      status: status ?? this.status,
      failureType: failureType ??
          (status == StateStatus.success ? null : this.failureType),
    );
  }
}
