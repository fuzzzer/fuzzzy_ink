import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'acceptance_reader_state.dart';

class AcceptanceReaderCubit extends Cubit<AcceptanceReaderState> {
  AcceptanceReaderCubit({
    required this.cryptoCoreService,
  }) : super(const AcceptanceReaderState(status: StateStatus.initial));

  final CryptoCoreService cryptoCoreService;

  Future<void> generateAcceptance({
    required String chatId,
  }) async {
    emit(state.copyWith(status: StateStatus.loading));

    final acceptanceRes = await cryptoCoreService.currentAcceptance(chatId);
    if (acceptanceRes is CryptoCoreFailure) {
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
        acceptance:
            (acceptanceRes as CryptoCoreSuccess<CryptoCoreAcceptance>).data,
      ),
    );
  }
}
