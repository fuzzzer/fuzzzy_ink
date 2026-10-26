// ignore_for_file: avoid_positional_boolean_parameters

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

part 'fuzzzy_cast_settings_state.dart';

/// The Fuzzzy Cast switches (DESIGN.md section 9): Fuzzzy Cast itself and
/// its soft sounds, both off by default and kept on this device.
class FuzzzyCastSettingsCubit extends Cubit<FuzzzyCastSettingsState> {
  FuzzzyCastSettingsCubit({required PreferencesService preferencesService})
      : _preferencesService = preferencesService,
        super(
          FuzzzyCastSettingsState(
            isEnabled: preferencesService.fuzzzyCastEnabled,
            softSounds: preferencesService.fuzzzyCastSoftSounds,
          ),
        ) {
    _appDataErasedSubscription =
        fuzzyHub.on<AppDataErased>().listen((_) => _readStored());
  }

  final PreferencesService _preferencesService;
  late final StreamSubscription<AppDataErased> _appDataErasedSubscription;

  @override
  Future<void> close() {
    _appDataErasedSubscription.cancel();
    return super.close();
  }

  /// After "Erase everything" the switches are what the (cleared) storage
  /// says, as after a restart.
  void _readStored() {
    emit(
      FuzzzyCastSettingsState(
        isEnabled: _preferencesService.fuzzzyCastEnabled,
        softSounds: _preferencesService.fuzzzyCastSoftSounds,
      ),
    );
  }

  Future<void> setEnabled(bool isEnabled) async {
    if (isEnabled == state.isEnabled) return;
    emit(state.copyWith(isEnabled: isEnabled));
    await _preferencesService.setFuzzzyCastEnabled(isEnabled);
  }

  /// Stored now. The cast package draws Fuzzz but carries no sounds (they are
  /// a separate package), so nothing plays yet; see the receipt.
  Future<void> setSoftSounds(bool softSounds) async {
    if (softSounds == state.softSounds) return;
    emit(state.copyWith(softSounds: softSounds));
    await _preferencesService.setFuzzzyCastSoftSounds(softSounds);
  }
}
