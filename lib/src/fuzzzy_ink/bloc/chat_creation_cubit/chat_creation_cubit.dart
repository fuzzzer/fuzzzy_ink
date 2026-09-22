import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'chat_creation_state.dart';

class ChatCreationCubit extends Cubit<ChatCreationState> {
  ChatCreationCubit({
    required this.cryptoCoreService,
    required this.chatGeneralDataListRepository,
  }) : super(const ChatCreationState(status: StateStatus.initial));

  final CryptoCoreService cryptoCoreService;
  final ChatGeneralDataListRepository chatGeneralDataListRepository;

  Future<void> createChat({
    required String chatName,
  }) async {
    emit(state.copyWith(status: StateStatus.loading, chatName: chatName));

    try {
      final restriction = await checkChatNameRestrictions(chatName);

      if (restriction != null) {
        emit(
          state.copyWith(
            status: StateStatus.failed,
            failure: ChatCreationFailure(
              type: restriction,
            ),
          ),
        );
        return;
      }

      final chatId = generateId();

      final invitationRes = await cryptoCoreService.createInvitation(chatId);
      if (invitationRes is CryptoCoreFailure) {
        emit(
          state.copyWith(
            status: StateStatus.failed,
            failure: ChatCreationFailure(
              type: ChatCreationFailureType.unknown,
            ),
          ),
        );
        return;
      }

      final chatData = ChatGeneralData(
        chatId: chatId,
        chatName: chatName,
        setupStatus: ChatSetupStatus.invited,
        didAcceptInvitation: false,
      );
      await chatGeneralDataListRepository.addChat(chatData);

      emit(
        state.copyWith(
          status: StateStatus.success,
          chatId: chatId,
          generatedChatInvitation:
              (invitationRes as CryptoCoreSuccess<CryptoCoreInvitation>).data,
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

  Future<ChatCreationFailureType?> checkChatNameRestrictions(
    String chatName,
  ) async {
    final name = await chatGeneralDataListRepository.getChatByName(chatName);

    if (name != null) {
      return ChatCreationFailureType.existingName;
    }

    return null;
  }
}
