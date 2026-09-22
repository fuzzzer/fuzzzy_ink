import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'invitation_reader_state.dart';

class InvitationReaderCubit extends Cubit<InvitationReaderState> {
  InvitationReaderCubit({
    required this.cryptoCoreService,
  }) : super(const InvitationReaderState(status: StateStatus.initial));

  final CryptoCoreService cryptoCoreService;

  Future<void> generateInvitation({
    required String chatId,
  }) async {
    emit(state.copyWith(status: StateStatus.loading));

    final invitationRes = await cryptoCoreService.currentInvitation(chatId);
    if (invitationRes is CryptoCoreFailure) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: DefaultFailure(),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: StateStatus.success,
        invitation:
            (invitationRes as CryptoCoreSuccess<CryptoCoreInvitation>).data,
      ),
    );
  }
}
