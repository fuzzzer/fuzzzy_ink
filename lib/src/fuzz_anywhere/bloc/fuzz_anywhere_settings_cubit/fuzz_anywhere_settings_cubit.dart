// ignore_for_file: avoid_positional_boolean_parameters

import 'package:bloc/bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

part 'fuzz_anywhere_settings_state.dart';

/// Settings → Other apps: "Lock from other apps" (off by default) and "Lock
/// again after each use" (on by default). They are sealed under the store
/// key, so they are read after each unlock; until the first one of a run
/// they are not known, and the feature counts as off.
class FuzzAnywhereSettingsCubit extends Cubit<FuzzAnywhereSettingsState> {
  FuzzAnywhereSettingsCubit({
    required FuzzAnywhereSettingsRepository repository,
  })  : _repository = repository,
        super(const FuzzAnywhereSettingsState());

  final FuzzAnywhereSettingsRepository _repository;

  /// Needs the open store; a blob that does not open reads as off.
  Future<void> load() async {
    final settings = await _repository.readSettings();
    if (isClosed) return;
    emit(FuzzAnywhereSettingsState(settings: settings, isLoaded: true));
  }

  /// Kept only when sealed and stored. Turning it off also forgets the
  /// person remembered for each other app.
  Future<bool> setOn(bool isOn) async {
    final saved = await _save(state.settings.copyWith(isOn: isOn));
    if (saved && !isOn) await _repository.forgetApps();
    return saved;
  }

  Future<bool> setLocksAgainAfterUse(bool locksAgain) =>
      _save(state.settings.copyWith(locksAgainAfterUse: locksAgain));

  Future<bool> _save(FuzzAnywhereSettings settings) async {
    final writeRes = await _repository.writeSettings(settings);
    if (writeRes is CryptoCoreFailure<void>) return false;
    if (!isClosed) {
      emit(FuzzAnywhereSettingsState(settings: settings, isLoaded: true));
    }
    return true;
  }
}
