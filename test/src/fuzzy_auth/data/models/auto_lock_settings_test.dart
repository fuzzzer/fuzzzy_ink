import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The auto-lock times are read back only as offered choices: a stored value
/// outside them (or anything malformed) is refused, so the standard applies.
void main() {
  test('round trip of every offered pair', () {
    for (final idle in AutoLockSettings.idleChoices) {
      for (final background in AutoLockSettings.backgroundChoices) {
        final settings = AutoLockSettings(idle: idle, background: background);
        expect(AutoLockSettings.fromJson(settings.toJson()), settings);
      }
    }
  });

  test('values outside the choices and malformed maps are refused', () {
    for (final json in <Object?>[
      null,
      'x',
      <String, dynamic>{},
      {'idleSeconds': 0, 'backgroundSeconds': 60},
      {'idleSeconds': 999999, 'backgroundSeconds': 60},
      {'idleSeconds': 300, 'backgroundSeconds': 3600},
      {'idleSeconds': '300', 'backgroundSeconds': 60},
    ]) {
      expect(AutoLockSettings.fromJson(json), isNull, reason: '$json');
    }
  });

  test('the standard: five idle minutes, one minute away', () {
    expect(AutoLockSettings.standard.idle, const Duration(minutes: 5));
    expect(AutoLockSettings.standard.background, const Duration(minutes: 1));
  });
}
