import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/components.dart';

export 'components/components.dart';

part 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> with WidgetsBindingObserver {
  ThemeCubit()
      : super(
          ThemeState(
            chosenBrightness: ChosenBrightness.dark,
          ),
        ) {
    WidgetsBinding.instance.addObserver(this);

    _getBrightnessPreferences().then((brightness) {
      if (brightness != null) {
        setBrightness(brightness);
      }
    });
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();

    if (state.chosenBrightness.isSystem) {
      emit(state.copyWith());
    }
  }

  Future<void> setBrightness(ChosenBrightness brightness) async {
    if (brightness != state.chosenBrightness) {
      emit(
        state.copyWith(
          chosenBrightness: brightness,
        ),
      );

      await _setBrightnessPreferences(brightness);
    }
  }

  final _brightnessPreferencesKey = 'brightness';
  final _lastAppBrightnessKey = 'lastAppBrightness';

  Future<void> _setBrightnessPreferences(ChosenBrightness brightness) async {
    final prefs = await SharedPreferences.getInstance();

    final valueMap = {
      _lastAppBrightnessKey: brightness.name,
    };

    await prefs.setString(_brightnessPreferencesKey, jsonEncode(valueMap));
  }

  Future<ChosenBrightness?> _getBrightnessPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final rawBrightnessPreferences = prefs.getString(_brightnessPreferencesKey);

    if (rawBrightnessPreferences == null) {
      return null;
    }

    final brightnessPreferences =
        jsonDecode(rawBrightnessPreferences) as Map<String, dynamic>;

    final lastAppBrightness = _brightnessFromString(
      (brightnessPreferences[_lastAppBrightnessKey] as String?) ?? '',
    );

    return lastAppBrightness;
  }

  ChosenBrightness? _brightnessFromString(String name) {
    try {
      return ChosenBrightness.values
          .where((brightness) => brightness.name == name)
          .first;
    } catch (ex) {
      return null;
    }
  }
}
