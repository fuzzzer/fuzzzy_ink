import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Georgian keeps one word per concept (company language room, Georgian
/// terminology record). These forms were used side by side before the
/// language pass of 2026-10-26; this test keeps them from coming back.
void main() {
  Map<String, String> georgianStrings() {
    final file = File('lib/src/core/l10n/app_ka.arb');
    final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final entry in arb.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value as String,
    };
  }

  // Georgian letters are not "word" characters for RegExp's \b, so word
  // starts are written out.
  const notAfterLetter = '(?<![ა-ჰ])';

  final banned = <String, RegExp>{
    // The app is "აპი" everywhere.
    'აპლიკაცია': RegExp('აპლიკაცი'),
    // The app locks (ჩაკეტვა) and unlocks (განბლოკვა); no "დაბლოკვა".
    'დაბლოკვა': RegExp('დაბლოკ'),
    // My safe is "ჩემი სეიფი"; the other vault words are not used.
    'ვოლტი': RegExp('$notAfterLetterვოლტ'),
    'საცავი': RegExp('$notAfterLetterსაცავ'),
    // One spelling for encrypt/decrypt (დაშიფვრა, გაშიფვრა).
    'დაშიფრვა': RegExp('შიფრვ'),
    // "გაგზავნეთ", not "გააგზავნეთ".
    'გააგზავნა': RegExp('გააგზავნ'),
    // People's names are never declined after a placeholder ("{name}-ის").
    'case ending after a placeholder': RegExp(r'\}-[ა-ჰ]'),
  };

  test('Georgian strings use one word per concept', () {
    final strings = georgianStrings();
    final found = [
      for (final MapEntry(key: form, value: pattern) in banned.entries)
        for (final MapEntry(:key, :value) in strings.entries)
          if (pattern.hasMatch(value)) '$key uses $form',
    ];
    expect(found, isEmpty);
  });
}
