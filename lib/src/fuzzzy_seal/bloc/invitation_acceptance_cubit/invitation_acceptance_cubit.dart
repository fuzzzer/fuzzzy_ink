import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'invitation_acceptance_state.dart';

class InvitationAcceptanceCubit extends Cubit<InvitationAcceptanceState> {
  InvitationAcceptanceCubit({
    required this.chatGeneralDataListRepository,
    required this.cryptoCoreService,
  }) : super(
          const InvitationAcceptanceState(
            status: StateStatus.initial,
          ),
        );

  final ChatGeneralDataListRepository chatGeneralDataListRepository;
  final CryptoCoreService cryptoCoreService;

  Future<void> acceptInvitation({
    required String invitationContent,
    required String chatName,
  }) async {
    emit(state.copyWith(status: StateStatus.loading));

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

      final chatIdRes = cryptoCoreService.peekChatId(invitationContent);
      if (chatIdRes is CryptoCoreFailure) {
        emit(
          state.copyWith(
            status: StateStatus.failed,
            failure: ChatCreationFailure(
              type: ChatCreationFailureType.invalidInvitation,
            ),
          ),
        );
        return;
      }
      final chatId = (chatIdRes as CryptoCoreSuccess<String>).data;

      final existingChat =
          await chatGeneralDataListRepository.getChatById(chatId);
      if (existingChat != null) {
        emit(
          state.copyWith(
            status: StateStatus.failed,
            failure: ChatCreationFailure(
              type: ChatCreationFailureType.ownInvitation,
            ),
          ),
        );
        return;
      }

      // No chat record → any core state under this id is an orphan of an
      // accept whose record never persisted; a stale one would make every
      // retry `internal`.
      await cryptoCoreService.deleteChat(chatId);

      final acceptanceRes = await cryptoCoreService.acceptInvitation(
        chatId: chatId,
        invitation: invitationContent,
      );
      if (acceptanceRes is CryptoCoreFailure) {
        emit(
          state.copyWith(
            status: StateStatus.failed,
            failure: ChatCreationFailure(
              type: _failureTypeOf((acceptanceRes as CryptoCoreFailure).type),
            ),
          ),
        );
        return;
      }

      final chatData = ChatGeneralData(
        chatId: chatId,
        chatName: chatName,
        setupStatus: ChatSetupStatus.connected,
        didAcceptInvitation: true,
      );

      await chatGeneralDataListRepository.addChat(chatData);

      emit(
        state.copyWith(
          status: StateStatus.success,
          chatData: chatData,
          generatedAcceptance:
              (acceptanceRes as CryptoCoreSuccess<CryptoCoreAcceptance>).data,
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

  static ChatCreationFailureType _failureTypeOf(CryptoCoreFailureType type) {
    return switch (type) {
      CryptoCoreFailureType.unsupportedFormat ||
      CryptoCoreFailureType.invalidSignature ||
      CryptoCoreFailureType.corrupt =>
        ChatCreationFailureType.invalidInvitation,
      _ => ChatCreationFailureType.unknown,
    };
  }
}
