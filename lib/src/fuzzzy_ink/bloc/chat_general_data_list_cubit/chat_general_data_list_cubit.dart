import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'chat_general_data_list_state.dart';

class ChatGeneralDataListCubit extends Cubit<ChatGeneralDataListState> {
  ChatGeneralDataListCubit({
    required this.cryptoCoreService,
    required this.chatRepository,
  }) : super(
          const ChatGeneralDataListState(
            status: StateStatus.initial,
          ),
        ) {
    _chatListUpdatesSubscription = chatRepository.chatListUpdates.listen((_) {
      _fetchChatsInBackground();
    });
  }

  final CryptoCoreService cryptoCoreService;

  final ChatGeneralDataListRepository chatRepository;
  late final StreamSubscription<ChatGeneralDataListUpdated>
      _chatListUpdatesSubscription;

  @override
  Future<void> close() {
    _chatListUpdatesSubscription.cancel();
    return super.close();
  }

  Future<void> fetchChats() async {
    emit(state.copyWith(status: StateStatus.loading));

    try {
      final chats = await chatRepository.getAllChats();

      emit(
        state.copyWith(
          status: StateStatus.success,
          chatList: chats,
        ),
      );
    } catch (ex) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: DefaultFailure(),
        ),
      );
    }
  }

  Future<void> _fetchChatsInBackground() async {
    try {
      final chats = await chatRepository.getAllChats();

      emit(
        state.copyWith(
          chatList: chats,
        ),
      );
    } catch (ex) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: DefaultFailure(),
        ),
      );
    }
  }

  Future<void> deleteChat({
    required String chatId,
  }) async {
    emit(
      state.copyWith(
        actionStatus: StateStatus.loading,
        actionType: ActionType.delete,
      ),
    );

    try {
      final deleteRes = await cryptoCoreService.deleteChat(chatId);
      if (deleteRes is CryptoCoreFailure) {
        emit(
          state.copyWith(
            actionStatus: StateStatus.failed,
            actionType: ActionType.delete,
            actionFailure: DefaultFailure(),
          ),
        );
        return;
      }
      await chatRepository.deleteChat(chatId);

      final updatedChats =
          state.chatList?.where((chat) => chat.chatId != chatId).toList();

      emit(
        state.copyWith(
          chatList: updatedChats,
          actionStatus: StateStatus.success,
          actionType: ActionType.delete,
        ),
      );
    } catch (ex) {
      logger.e('ERROR: $ex');

      emit(
        state.copyWith(
          actionStatus: StateStatus.failed,
          actionType: ActionType.delete,
          actionFailure: DefaultFailure(),
        ),
      );
    }
  }

  Future<void> updateChat({
    required ChatGeneralData chat,
  }) async {
    emit(
      state.copyWith(
        actionStatus: StateStatus.loading,
        actionType: ActionType.update,
      ),
    );

    try {
      await chatRepository.updateChat(chat);

      final updatedChats = state.chatList?.map((existingChat) {
        return existingChat.chatId == chat.chatId ? chat : existingChat;
      }).toList();

      emit(
        state.copyWith(
          chatList: updatedChats,
          actionStatus: StateStatus.success,
          actionType: ActionType.update,
        ),
      );
    } catch (ex) {
      logger.e('ERROR: $ex');

      emit(
        state.copyWith(
          actionStatus: StateStatus.failed,
          actionType: ActionType.update,
          actionFailure: DefaultFailure(),
        ),
      );
    }
  }

  void resetActionStatus() {
    emit(
      state.copyWith(
        actionStatus: StateStatus.initial,
        actionType: ActionType.none,
      ),
    );
  }
}
