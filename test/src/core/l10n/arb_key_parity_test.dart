import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `app_en.arb` and `app_ka.arb` must carry the same keys, none of them
/// empty — Georgian is required for every string (project rule).
void main() {
  Map<String, dynamic> readArb(String locale) {
    final file = File('lib/src/core/l10n/app_$locale.arb');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  test('en and ka arb files have identical key sets and no empty values', () {
    final en = readArb('en');
    final ka = readArb('ka');

    expect(ka.keys.toSet(), en.keys.toSet());
    for (final arb in [en, ka]) {
      for (final entry in arb.entries) {
        if (entry.key.startsWith('@')) continue;
        expect(
          entry.value,
          isA<String>().having((s) => s.trim(), 'text', isNotEmpty),
          reason: entry.key,
        );
      }
    }
  });

  /// Keys whose Georgian text is, on purpose, the same as the English: brand
  /// and product names stay in Latin letters, and "Fuzz" is the app's own
  /// technical term (Georgian writes "Fuzz-ის კოპირება").
  const sameInBothLanguages = {
    'fuzzzyInk', // "Fuzzzy Ink" — the brand
    'fuzz', // "Fuzz" — the encrypted text, a technical term
    'fuzzzyCast', // "Fuzzzy Cast" — the character layer's name stays Latin
    'languageEnglish', // a language is named in its own language
    'languageGeorgian', // "ქართული" in both lists, for the same reason
  };

  test('every Georgian string is translated (T-0413)', () {
    final en = readArb('en');
    final ka = readArb('ka');

    final untranslated = [
      for (final key in en.keys)
        if (!key.startsWith('@') &&
            !sameInBothLanguages.contains(key) &&
            ka[key] == en[key])
          key,
    ];
    expect(untranslated, isEmpty, reason: 'still English in app_ka.arb');
  });

  test('the allowlist only names keys that exist and are still identical', () {
    final en = readArb('en');
    final ka = readArb('ka');
    for (final key in sameInBothLanguages) {
      expect(en[key], isNotNull, reason: key);
      expect(ka[key], en[key], reason: '$key is translated now: drop it');
    }
  });
}
