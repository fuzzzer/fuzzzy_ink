import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Every quick-unlock string names the device's own kind in both languages
/// ("Face ID", never "fingerprint", on a Face ID phone — final regression
/// 2026-10-26).
void main() {
  test('the device answer maps to a kind; anything else is the generic one',
      () {
    expect(BiometricKind.fromName('faceId'), BiometricKind.faceId);
    expect(BiometricKind.fromName('touchId'), BiometricKind.touchId);
    expect(BiometricKind.fromName('fingerprint'), BiometricKind.fingerprint);
    expect(BiometricKind.fromName('face'), BiometricKind.face);
    expect(BiometricKind.fromName('opticId'), BiometricKind.other);
    expect(BiometricKind.fromName(null), BiometricKind.other);
  });

  test('a face gets a face icon, the rest a fingerprint', () {
    expect(BiometricKind.faceId.icon, Icons.face_unlock_outlined);
    expect(BiometricKind.face.icon, Icons.face_unlock_outlined);
    expect(BiometricKind.touchId.icon, Icons.fingerprint);
    expect(BiometricKind.other.icon, Icons.fingerprint);
  });

  for (final locale in FuzzzyInkLocalizations.supportedLocales) {
    test('${locale.languageCode}: each kind has its own words', () {
      final l10n = lookupFuzzzyInkLocalizations(locale);
      final strings = <String Function(String)>[
        l10n.accessBioTitle,
        l10n.accessUseBio,
        l10n.safeOpenWithFingerprint,
        l10n.accessFingerprintOrFace,
        l10n.accessTurnOnBioTitle,
        l10n.accessTurnOnSafeBioTitle,
        l10n.accessBioOn,
        l10n.accessBioChanged,
      ];
      final fingerprintWord = locale.languageCode == 'ka' ? 'თითის' : 'inger';
      for (final string in strings) {
        final texts = {
          for (final kind in BiometricKind.values) string(kind.l10nKey),
        };
        expect(texts, hasLength(BiometricKind.values.length));
        for (final kind in [BiometricKind.faceId, BiometricKind.touchId]) {
          final text = string(kind.l10nKey);
          expect(
            text,
            contains(kind == BiometricKind.faceId ? 'Face ID' : 'Touch ID'),
          );
          expect(text, isNot(contains(fingerprintWord)));
        }
        expect(
          string(BiometricKind.face.l10nKey),
          isNot(contains(fingerprintWord)),
        );
      }
    });
  }
}
