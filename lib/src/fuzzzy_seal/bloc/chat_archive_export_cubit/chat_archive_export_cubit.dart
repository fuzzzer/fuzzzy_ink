import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'chat_archive_export_state.dart';

class ChatArchiveExportCubit extends Cubit<ChatArchiveExportState> {
  ChatArchiveExportCubit({
    required this.chatArchiveRepository,
  }) : super(const ChatArchiveExportState());

  final ChatArchiveRepository chatArchiveRepository;

  Future<void> exportChat({
    required String chatId,
    required String chatName,
    required String password,
    required String outputPath,
  }) async {
    emit(state.copyWith(status: StateStatus.loading));

    final res = await chatArchiveRepository.exportChat(
      chatId: chatId,
      chatName: chatName,
      password: password,
      outputPath: outputPath,
    );

    if (res is ChatArchiveFailure<void>) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: res.type,
        ),
      );
      return;
    }

    emit(state.copyWith(status: StateStatus.success));
  }
}
