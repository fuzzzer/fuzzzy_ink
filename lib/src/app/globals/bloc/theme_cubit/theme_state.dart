part of 'theme_cubit.dart';

class ThemeState {
  final ChosenBrightness chosenBrightness;

  ThemeState({
    required this.chosenBrightness,
  });

  ThemeState copyWith({
    ChosenBrightness? chosenBrightness,
  }) {
    return ThemeState(
      chosenBrightness: chosenBrightness ?? this.chosenBrightness,
    );
  }
}
