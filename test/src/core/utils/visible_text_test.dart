import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

void main() {
  test('hidden and direction marks show as their codes, as on the sheet', () {
    // The Android sheet showed this selection as
    // "zw[U+200B] rtl[U+202E]TXET" (Fuzzzy Tester, 1.1.5+12).
    expect(
      VisibleText.of('zw\u200B rtl\u202ETXET'),
      'zw[U+200B] rtl[U+202E]TXET',
    );
    expect(
        VisibleText.of('a\u2066b\u2069\uFEFF'), 'a[U+2066]b[U+2069][U+FEFF]');
    expect(VisibleText.of('\u0000\u00AD'), '[U+0000][U+00AD]');
  });

  test('words, line breaks, Georgian and emoji stay as they are', () {
    const text = 'გამარჯობა\nNino\t👋🏽 👨‍👩‍👧 ❤️';
    expect(VisibleText.of(text), text);
  });
}
