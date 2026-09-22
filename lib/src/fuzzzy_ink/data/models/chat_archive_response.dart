import 'package:fuzzzy_ink/lib.dart';

sealed class ChatArchiveResponse<T> {
  const ChatArchiveResponse();
}

class ChatArchiveSuccess<T> extends ChatArchiveResponse<T> {
  const ChatArchiveSuccess(this.data);
  final T data;
}

class ChatArchiveFailure<T> extends ChatArchiveResponse<T> {
  const ChatArchiveFailure(this.type);
  final ChatArchiveExportFailureType type;
}
