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
}
