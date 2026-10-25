// ignore_for_file: avoid_positional_boolean_parameters

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
        );

  final PreferencesService _preferencesService;

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
