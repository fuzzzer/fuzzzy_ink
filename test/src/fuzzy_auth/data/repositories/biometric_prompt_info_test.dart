import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

/// The system fingerprint / Face ID prompt follows the app's language
/// (T-0413): nothing in it is hard-coded English.
void main() {
  final ka = FuzzzyInkLocalizationsKa();
  final en = FuzzzyInkLocalizationsEn();

  List<String> texts(PromptInfo info) => [
        info.androidPromptInfo.title,
        info.androidPromptInfo.subtitle!,
        info.androidPromptInfo.negativeButton,
        info.iosPromptInfo.saveTitle,
        info.iosPromptInfo.accessTitle,
        info.macOsPromptInfo.saveTitle,
        info.macOsPromptInfo.accessTitle,
      ];

  test('the chat prompt is Georgian in Georgian', () {
    final info = biometricPromptInfo(BiometricScope.chat, ka);

    expect(info.androidPromptInfo.title, 'Fuzzzy Ink-ის განბლოკვა');
    expect(info.androidPromptInfo.subtitle, ka.biometricUnlockChats);
    expect(info.androidPromptInfo.negativeButton, 'გაუქმება');
    expect(info.iosPromptInfo.accessTitle, ka.biometricUnlockChats);
    expect(info.macOsPromptInfo.saveTitle, ka.biometricSavePassword);
  });

  test('no prompt text is the English one when the app is in Georgian', () {
    for (final scope in BiometricScope.values) {
      final georgian = texts(biometricPromptInfo(scope, ka));
      final english = texts(biometricPromptInfo(scope, en));
      for (var i = 0; i < georgian.length; i++) {
        expect(georgian[i], isNot(english[i]), reason: '$scope field $i');
      }
    }
  });

  test('English prompt texts use the current names', () {
    final chat = biometricPromptInfo(BiometricScope.chat, en);
    expect(chat.androidPromptInfo.title, 'Unlock Fuzzzy Ink');
    expect(chat.androidPromptInfo.subtitle,
        "Confirm it's you to unlock Fuzzzy Ink");
    expect(chat.iosPromptInfo.saveTitle, 'Authenticate to save password');

    final vault = biometricPromptInfo(BiometricScope.vault, en);
    expect(vault.androidPromptInfo.title, 'Open My safe');
    expect(vault.iosPromptInfo.accessTitle, "Confirm it's you to open My safe");
  });
}
