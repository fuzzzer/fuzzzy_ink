import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'connected_chat_state.dart';

/// A person's history, newest first, read page by page from the sealed rows.
class ConnectedChatCubit extends Cubit<ConnectedChatState> {
  ConnectedChatCubit({
    required this.messageDataRepository,
    required this.chatId,
    this.messagesPerPage = 8,
  }) : super(
          const ConnectedChatState(
            status: StateStatus.initial,
            messages: [],
          ),
        ) {
    _newMessageUpdatesSubscription =
        messageDataRepository.newMessageUpdates.listen(_addNewMessage);
  }

  late final StreamSubscription<NewMessageAdded> _newMessageUpdatesSubscription;

  final MessageDataRepository messageDataRepository;

  final String chatId;

  final int messagesPerPage;
  int currentPage = 0;

  @override
  Future<void> close() {
    _newMessageUpdatesSubscription.cancel();
    return super.close();
  }

  /// A row Lock or Open wrote for this person while the page is open.
  void _addNewMessage(NewMessageAdded newMessageAdded) {
    emit(
      state.copyWith(
        messages: [
          newMessageAdded.message,
          ...state.messages,
        ],
      ),
    );
  }

  Future<void> loadInitialMessages() async {
    emit(
      state.copyWith(
        hasFetchedAllMessages: false,
      ),
    );
    currentPage = 0;

    await loadCurrentMessagesPage();
  }

  /// Reads the pages loaded so far again, from the newest row: a person's
  /// page coming back after Lock or Open added a row there. The list is
  /// replaced, never appended to.
  Future<void> reloadMessages() async {
    final pages = currentPage + 1;
    emit(
      state.copyWith(
        status: StateStatus.loading,
        messages: const [],
        hasFetchedAllMessages: false,
      ),
    );
    currentPage = 0;
    await loadCurrentMessagesPage();
    while (currentPage + 1 < pages &&
        state.status.isSuccess &&
        !state.hasFetchedAllMessages) {
      currentPage++;
      await loadCurrentMessagesPage();
    }
  }

  Future<void> loadOlderMessages() async {
    if (state.status.isLoading || state.hasFetchedAllMessages) return;
    currentPage++;
    await loadCurrentMessagesPage();
  }

  Future<void> loadCurrentMessagesPage() async {
    emit(
      state.copyWith(
        status: StateStatus.loading,
      ),
    );

    try {
      final paginatedMessages =
          await messageDataRepository.getMessagesForChatPaginated(
        chatId,
        pageSize: messagesPerPage,
        pageIndex: currentPage,
      );

      if (paginatedMessages.isEmpty) {
        emit(
          state.copyWith(
            status: StateStatus.success,
            hasFetchedAllMessages: true,
          ),
        );
        return;
      }

      // The repository has already opened each row's local seal.
      final updatedMessages = [
        ...state.messages,
        ...paginatedMessages,
      ];

      emit(
        state.copyWith(
          status: StateStatus.success,
          messages: updatedMessages,
        ),
      );
    } catch (ex) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: DefaultFailure(
            message: ex.toString(),
          ),
        ),
      );
    }
  }
}
