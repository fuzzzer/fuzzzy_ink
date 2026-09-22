import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'safety_number_state.dart';

/// The chat's safety number and its verified flag. Both are read from — and
/// the flag written to — the crypto core, which is the only source of truth
/// for `verified` (it resets with the keys on a re-pair).
class SafetyNumberCubit extends Cubit<SafetyNumberState> {
  SafetyNumberCubit({
    required this.chatId,
    required this.cryptoCoreService,
  }) : super(const SafetyNumberState(status: StateStatus.initial));

  final String chatId;
  final CryptoCoreService cryptoCoreService;

  Future<void> load() async {
    emit(state.copyWith(status: StateStatus.loading));

    final numberRes = await cryptoCoreService.safetyNumber(chatId);
    if (numberRes is CryptoCoreFailure<String>) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: DefaultFailure(),
        ),
      );
      return;
    }

    final verifiedRes = await cryptoCoreService.isVerified(chatId);
    if (verifiedRes is CryptoCoreFailure<bool>) {
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
        safetyNumber: (numberRes as CryptoCoreSuccess<String>).data,
        isVerified: (verifiedRes as CryptoCoreSuccess<bool>).data,
      ),
    );
  }

  /// Flips the flag in the core first; the state follows only once it is on
  /// disk.
  Future<void> toggleVerified() async {
    final verified = !state.isVerified;

    final markRes = await cryptoCoreService.markVerified(
      chatId: chatId,
      verified: verified,
    );
    if (markRes is CryptoCoreFailure) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: DefaultFailure(),
        ),
      );
      return;
    }

    emit(state.copyWith(isVerified: verified));
  }
}
