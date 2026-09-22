import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'handshake_state.dart';

class HandshakeCubit extends Cubit<HandshakeState> {
  HandshakeCubit({
    required this.cryptoCoreService,
    required this.chatGeneralDataListRepository,
  }) : super(const HandshakeState(status: StateStatus.initial));

  final CryptoCoreService cryptoCoreService;
  final ChatGeneralDataListRepository chatGeneralDataListRepository;

  Future<void> completeHandshake({
    required String acceptanceContent,
    required String chatId,
  }) async {
    emit(state.copyWith(status: StateStatus.loading));

    try {
      final handshakeRes = await cryptoCoreService.completeHandshake(
        chatId: chatId,
        acceptance: acceptanceContent,
      );
      if (handshakeRes is CryptoCoreFailure) {
        emit(
          state.copyWith(
            status: StateStatus.failed,
            failure: ChatCreationFailure(
              type: _failureTypeOf(handshakeRes.type),
            ),
          ),
        );
        return;
      }

      final chatData = await chatGeneralDataListRepository.getChatById(chatId);
      if (chatData != null) {
        final updatedChatData =
            chatData.copyWith(setupStatus: ChatSetupStatus.connected);
        await chatGeneralDataListRepository.updateChat(updatedChatData);
      }

      emit(
        state.copyWith(
          status: StateStatus.success,
          chatData: chatData,
        ),
      );
    } catch (ex) {
      logger.e('ERROR: $ex');

      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: ChatCreationFailure(
            internalMessage: ex.toString(),
            type: ChatCreationFailureType.unknown,
          ),
        ),
      );
    }
  }

  static ChatCreationFailureType _failureTypeOf(CryptoCoreFailureType type) {
    return switch (type) {
      CryptoCoreFailureType.invitationAlreadyUsed =>
        ChatCreationFailureType.invitationAlreadyUsed,
      CryptoCoreFailureType.wrongChat => ChatCreationFailureType.wrongChat,
      CryptoCoreFailureType.unsupportedFormat ||
      CryptoCoreFailureType.invalidSignature ||
      CryptoCoreFailureType.corrupt =>
        ChatCreationFailureType.invalidAcceptance,
      _ => ChatCreationFailureType.unknown,
    };
  }
}
