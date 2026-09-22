import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'connected_chat_state.dart';

class ConnectedChatCubit extends Cubit<ConnectedChatState> {
  ConnectedChatCubit({
    required this.messageDataRepository,
    required this.cryptoCoreService,
    required this.chatId,
    this.messagesPerPage = 8,
  }) : super(
          const ConnectedChatState(
            status: StateStatus.initial,
            messages: [],
          ),
        ) {
    _newMessageUpdatesSubscription = messageDataRepository.newMessageUpdates
        .listen(addNewMessageInBackground);
  }

  late final StreamSubscription<NewMessageAdded> _newMessageUpdatesSubscription;

  final MessageDataRepository messageDataRepository;
  final CryptoCoreService cryptoCoreService;

  final String chatId;

  final int messagesPerPage;
  int currentPage = 0;

  @override
  Future<void> close() {
    _newMessageUpdatesSubscription.cancel();
    return super.close();
  }

  Future<void> addNewMessageInBackground(
    NewMessageAdded newMessageAdded,
  ) async {
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

  Future<void> sendMessage({
    required String text,
  }) async {
    emit(
      state.copyWith(
        actionStatus: StateStatus.loading,
        actionType: ChatActionType.sendMessage,
      ),
    );

    final encryptRes = await cryptoCoreService.encryptText(
      chatId: chatId,
      text: text,
    );

    if (encryptRes is CryptoCoreFailure<String>) {
      emit(
        state.copyWith(
          actionStatus: StateStatus.failed,
          actionType: ChatActionType.sendMessage,
          actionFailure: ConnectedChatFailure(
            type: _failureTypeOf(encryptRes.type),
          ),
        ),
      );
      return;
    }

    final blob = (encryptRes as CryptoCoreSuccess<String>).data;

    try {
      // The ratchet has moved on: this seal-and-store is the only copy of
      // the plaintext a sender will ever be able to read back.
      final message = MessageData(
        id: 0,
        type: MessageType.text,
        chatId: chatId,
        encryptedMessage: blob.substring(fuzzIdentificator.length),
        decryptedMessage: text,
        sentAt: DateTime.now(),
        isSent: true,
      );

      final newMessageId = await messageDataRepository.addMessage(message);

      final preparedNewMessage = message.copyWith(
        id: newMessageId,
        sentAt: DateTime.now(),
      );

      emit(
        state.copyWith(
          messages: [
            preparedNewMessage,
            ...state.messages,
          ],
          actionStatus: StateStatus.success,
          actionType: ChatActionType.sendMessage,
        ),
      );
    } catch (ex) {
      logger.e('ERROR: $ex');

      emit(
        state.copyWith(
          actionStatus: StateStatus.failed,
          actionType: ChatActionType.sendMessage,
          actionFailure: ConnectedChatFailure(
            type: ConnectedChatFailureType.unknown,
          ),
        ),
      );
    }
  }

  Future<void> receiveMessage({
    required String encryptedText,
  }) async {
    emit(
      state.copyWith(
        actionStatus: StateStatus.loading,
        actionType: ChatActionType.receiveMessage,
      ),
    );

    final decryptRes = await cryptoCoreService.decryptText(
      chatId: chatId,
      blob: '$fuzzIdentificator$encryptedText',
    );

    if (decryptRes is CryptoCoreFailure<String>) {
      emit(
        state.copyWith(
          actionStatus: StateStatus.failed,
          actionType: ChatActionType.receiveMessage,
          actionFailure: ConnectedChatFailure(
            type: _failureTypeOf(decryptRes.type),
          ),
        ),
      );
      return;
    }

    final decryptedMessage = (decryptRes as CryptoCoreSuccess<String>).data;

    try {
      // The core has already persisted the advanced ratchet, so the blob can
      // never be unfuzzed again: the sealed row must be on disk before the
      // message is shown, or a crash in between loses the plaintext.
      final message = MessageData(
        id: 0,
        chatId: chatId,
        type: MessageType.text,
        encryptedMessage: encryptedText,
        decryptedMessage: decryptedMessage,
        sentAt: DateTime.now(),
        isSent: false,
      );

      final newMessageId = await messageDataRepository.addMessage(message);

      final preparedNewMessage = message.copyWith(
        id: newMessageId,
        sentAt: DateTime.now(),
      );

      emit(
        state.copyWith(
          messages: [
            preparedNewMessage,
            ...state.messages,
          ],
          actionStatus: StateStatus.success,
          actionType: ChatActionType.receiveMessage,
        ),
      );
    } catch (ex) {
      logger.e('ERROR: $ex');

      emit(
        state.copyWith(
          actionStatus: StateStatus.failed,
          actionType: ChatActionType.receiveMessage,
          actionFailure: ConnectedChatFailure(
            type: ConnectedChatFailureType.unknown,
          ),
        ),
      );
    }
  }

  Future<void> deleteMessage({
    required int messageId,
  }) async {
    emit(
      state.copyWith(
        actionStatus: StateStatus.loading,
        actionType: ChatActionType.deleteMessage,
      ),
    );

    try {
      await messageDataRepository.deleteMessage(messageId);

      final updatedMessages =
          state.messages.where((message) => message.id != messageId).toList();
      emit(
        state.copyWith(
          messages: updatedMessages,
          actionStatus: StateStatus.success,
          actionType: ChatActionType.deleteMessage,
        ),
      );
    } catch (ex) {
      logger.e('ERROR: $ex');

      emit(
        state.copyWith(
          actionStatus: StateStatus.failed,
          actionType: ChatActionType.deleteMessage,
          actionFailure: ConnectedChatFailure(
            type: ConnectedChatFailureType.unknown,
          ),
        ),
      );
    }
  }

  Future<void> deleteAllMessages() async {
    emit(
      state.copyWith(
        actionStatus: StateStatus.loading,
        actionType: ChatActionType.deleteAllMessages,
      ),
    );

    try {
      await messageDataRepository.deleteAllMessagesForChat(chatId);

      emit(
        state.copyWith(
          messages: [],
          actionStatus: StateStatus.success,
          actionType: ChatActionType.deleteAllMessages,
        ),
      );
    } catch (ex) {
      logger.e('ERROR: $ex');

      emit(
        state.copyWith(
          actionStatus: StateStatus.failed,
          actionType: ChatActionType.deleteAllMessages,
          actionFailure: ConnectedChatFailure(
            type: ConnectedChatFailureType.unknown,
          ),
        ),
      );
    }
  }

  static ConnectedChatFailureType _failureTypeOf(CryptoCoreFailureType type) {
    return switch (type) {
      CryptoCoreFailureType.replay => ConnectedChatFailureType.alreadyUnfuzzed,
      CryptoCoreFailureType.wrongChat => ConnectedChatFailureType.wrongChat,
      CryptoCoreFailureType.tooOld => ConnectedChatFailureType.tooOld,
      CryptoCoreFailureType.corrupt ||
      CryptoCoreFailureType.unsupportedFormat =>
        ConnectedChatFailureType.corrupt,
      _ => ConnectedChatFailureType.unknown,
    };
  }
}
