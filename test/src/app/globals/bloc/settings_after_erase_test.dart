import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Erase everything" clears the stored settings; the ones held in memory
/// follow at once instead of after a restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fuzzzy Cast, language and look go back to what storage says', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cast = FuzzzyCastSettingsCubit(
      preferencesService: PreferencesService(prefs),
    );
    final language = LocalizationCubit();
    final look = ThemeCubit();
    await pumpEventQueue();

    await cast.setEnabled(true);
    await language.changeLocale(const Locale('en'));
    await look.setBrightness(ChosenBrightness.dark);
    expect(cast.state.isEnabled, isTrue);
    expect(language.state.followsPhone, isFalse);

    await prefs.clear();
    fuzzyHub.sendSignal(const AppDataErased());
    await pumpEventQueue();

    expect(cast.state.isEnabled, isFalse);
    expect(language.state.followsPhone, isTrue);
    expect(look.state.chosenBrightness, ChosenBrightness.system);

    await Future.wait([cast.close(), language.close(), look.close()]);
  });

  test('the first run keeps its language and look through its own erase',
      () async {
    SharedPreferences.setMockInitialValues({});
    final language = LocalizationCubit();
    final look = ThemeCubit();
    await pumpEventQueue();

    await language.changeLocale(const Locale('en'));
    await look.setBrightness(ChosenBrightness.light);
    fuzzyHub.sendSignal(const AppDataErased());
    await pumpEventQueue();

    expect(language.state.followsPhone, isFalse);
    expect(language.state.locale, const Locale('en'));
    expect(look.state.chosenBrightness, ChosenBrightness.light);

    await Future.wait([language.close(), look.close()]);
  });
}
