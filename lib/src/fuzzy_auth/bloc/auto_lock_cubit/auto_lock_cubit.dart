import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The auto-lock times the whole app runs on. They are sealed under the
/// store key, so they load after each unlock; until then the standard times
/// apply.
class AutoLockCubit extends Cubit<AutoLockSettings> {
  AutoLockCubit({required AutoLockSettingsRepository repository})
      : _repository = repository,
        super(AutoLockSettings.standard);

  final AutoLockSettingsRepository _repository;

  Future<void> load() async {
    emit(await _repository.read());
  }

  /// Kept only when it was sealed and stored; the times on screen are the
  /// times in force.
  Future<bool> update(AutoLockSettings settings) async {
    final writeRes = await _repository.write(settings);
    if (writeRes is CryptoCoreFailure<void>) return false;
    emit(settings);
    return true;
  }
}
