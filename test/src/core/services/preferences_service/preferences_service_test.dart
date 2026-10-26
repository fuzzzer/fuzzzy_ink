import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Erase everything clears every preference; the first run's own erase puts
/// back what its welcome set (seen live 2026-10-26: finishing the first run
/// landed on the welcome again, because its erase forgot it was seen).
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'language_code': 'ka',
      'brightness': '{"lastAppBrightness":"dark"}',
      'paired_acceptance_x': 'reply',
      'fuzzzy_cast_enabled': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  test('clearAll clears every preference', () async {
    await PreferencesService(prefs).clearAll();
    expect(prefs.getKeys(), isEmpty);
  });

  test('clearAll keeps the first-run choices when asked', () async {
    final service = PreferencesService(prefs);
    await service.clearAll(keep: PreferencesService.firstRunChoiceKeys);
    expect(service.hasSeenOnboarding, isTrue);
    expect(prefs.getString('language_code'), 'ka');
    expect(prefs.getString('brightness'), '{"lastAppBrightness":"dark"}');
    expect(prefs.containsKey('paired_acceptance_x'), isFalse);
    expect(prefs.containsKey('fuzzzy_cast_enabled'), isFalse);
  });
}
