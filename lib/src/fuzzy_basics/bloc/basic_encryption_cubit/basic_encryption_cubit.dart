import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'basic_encryption_state.dart';

class BasicEncryptionCubit extends Cubit<BasicEncryptionState> {
  final CryptoCoreService cryptoCoreService;

  BasicEncryptionCubit({
    required this.cryptoCoreService,
  }) : super(const BasicEncryptionState(status: StateStatus.initial));

  Future<void> encryptText({required String text, required String key}) async {
    if (text.isEmpty || key.isEmpty) {
      emit(
        BasicEncryptionState(
          status: StateStatus.failed,
          failure: DefaultFailure(message: 'textAndKeyCannotBeEmpty'),
        ),
      );
      return;
    }
    emit(state.copyWith(status: StateStatus.loading));

    final res = await cryptoCoreService.passwordSealText(
      password: key,
      text: text,
    );

    if (res is CryptoCoreFailure<String>) {
      emit(
        BasicEncryptionState(
          status: StateStatus.failed,
          failure: DefaultFailure(message: 'encryptionFailed'),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: StateStatus.success,
        result: (res as CryptoCoreSuccess<String>).data,
      ),
    );
  }

  Future<void> decryptText({
    required String encryptedText,
    required String key,
  }) async {
    if (encryptedText.isEmpty || key.isEmpty) {
      emit(
        BasicEncryptionState(
          status: StateStatus.failed,
          failure: DefaultFailure(message: 'encryptedTextAndKeyCannotBeEmpty'),
        ),
      );
      return;
    }
    emit(state.copyWith(status: StateStatus.loading));

    final res = await cryptoCoreService.passwordOpenText(
      password: key,
      blob: encryptedText,
    );

    if (res is CryptoCoreFailure<String>) {
      emit(
        BasicEncryptionState(
          status: StateStatus.failed,
          failure:
              DefaultFailure(message: _decryptionFailureMessageOf(res.type)),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: StateStatus.success,
        result: (res as CryptoCoreSuccess<String>).data,
      ),
    );
  }

  /// A tampered blob is indistinguishable from a wrong key (the AEAD tag
  /// fails either way), so both read as "incorrect key"; only a string that
  /// is not a fuzzed text at all reads as invalid.
  static String _decryptionFailureMessageOf(CryptoCoreFailureType type) {
    return switch (type) {
      CryptoCoreFailureType.wrongPassword => 'basicsWrongPassword',
      CryptoCoreFailureType.corrupt ||
      CryptoCoreFailureType.unsupportedFormat =>
        'corruptBlob',
      _ => 'decryptionFailedCheckYourKeyOrEncryptedText',
    };
  }
}
