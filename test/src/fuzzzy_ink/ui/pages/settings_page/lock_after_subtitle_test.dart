import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// "Lock the app" row: "After 5 minutes", but "Right away" alone — never
/// "After Right away" (QA 2026-10-26).
void main() {
  for (final l10n in [FuzzzyInkLocalizationsEn(), FuzzzyInkLocalizationsKa()]) {
    test('the subtitle reads naturally (${l10n.localeName})', () {
      expect(
        SettingsKeepingSafeSection.lockAfterSubtitle(l10n, 0),
        l10n.accessRightAway,
      );
      expect(
        SettingsKeepingSafeSection.lockAfterSubtitle(l10n, 2),
        l10n.accessLockAfter(l10n.accessFiveMinutes),
      );
    });
  }
}
