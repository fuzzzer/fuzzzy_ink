import 'package:flutter/material.dart';

enum ChosenBrightness {
  light,
  dark,
  system;

  bool get isLight => this == ChosenBrightness.light;
  bool get isDark => this == ChosenBrightness.dark;
  bool get isSystem => this == ChosenBrightness.system;

  static ChosenBrightness fromBrightness(Brightness brightness) {
    return switch (brightness) {
      Brightness.dark => ChosenBrightness.dark,
      Brightness.light => ChosenBrightness.light,
    };
  }

  Brightness toBrightness() {
    return isSystem
        ? WidgetsBinding.instance.platformDispatcher.platformBrightness.isLight
            ? Brightness.light
            : Brightness.dark
        : isLight
            ? Brightness.light
            : Brightness.dark;
  }
}

extension ChosenBrightnessThemeMode on ChosenBrightness {
  ThemeMode get themeMode => switch (this) {
        ChosenBrightness.light => ThemeMode.light,
        ChosenBrightness.dark => ThemeMode.dark,
        ChosenBrightness.system => ThemeMode.system,
      };
}

extension BrightnessExtension on Brightness {
  bool get isLight => this == Brightness.light;
  bool get isDark => this == Brightness.dark;
}
