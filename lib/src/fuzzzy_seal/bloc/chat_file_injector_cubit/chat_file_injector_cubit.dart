import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'chat_file_injector_state.dart';

class ChatFileInjectorCubit extends Cubit<ChatFileInjectorState> {
  ChatFileInjectorCubit({
    required this.messageDataRepository,
  }) : super(
          const ChatFileInjectorState(
            status: StateStatus.initial,
          ),
        );

  final MessageDataRepository messageDataRepository;

  Future<void> injectProcessedFile({
    required List<FileProcessingData> processedFiles,
    required bool filesAreEncrypted,
  }) async {
    if (processedFiles.isEmpty) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: StateStatus.loading,
      ),
    );

    final List<Future<int>> addMessageFutures = [];
    final List<FileProcessingData> failedToAddProcessedFiles = [];

    for (final file in processedFiles) {
      final outputPath = file.outputFilePath;

      if (outputPath == null) {
        failedToAddProcessedFiles.add(file);
        continue;
      }

      if (file.status == FileProcessingStatus.completed) {
        final message = MessageData(
          id: 0,
          type: MessageType.file,
          chatId: file.chatId,
          encryptedMessage: outputPath,
          decryptedMessage: '',
          sentAt: DateTime.now(),
          isSent: filesAreEncrypted,
        );

        final addMessageFuture = messageDataRepository.addMessage(
          message,
          notifyListeners: true,
        );

        addMessageFutures.add(addMessageFuture);
      } else {
        failedToAddProcessedFiles.add(file);
      }
    }

    await addMessageFutures.wait;

    emit(
      state.copyWith(
        status: StateStatus.success,
        failedToAddProcessedFiles: failedToAddProcessedFiles,
      ),
    );
  }
}
