import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

import '../../../../helpers/redesign_harness.dart';

/// On a Georgian screen the back button is read aloud in Georgian ("უკან"),
/// not in English: the kit's own back buttons always said "Back".
void main() {
  const georgian = Locale('ka');

  testWidgets('an access screen reads its back arrow in Georgian',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var backs = 0;
    await pumpRedesign(
      tester,
      AccessPage(
        qaId: 'recover.key',
        title: 'title',
        onBack: () => backs++,
        children: const [SizedBox.shrink()],
      ),
      locale: georgian,
    );

    expect(find.bySemanticsLabel('უკან'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Back')), findsNothing);

    // The kit's QA key stays.
    await tester.tap(find.byKey(const Key('recover.key.back')));
    expect(backs, 1);
    semantics.dispose();
  });

  testWidgets('an older screen reads its bottom back button in Georgian',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRedesign(tester, const AboutEncryptionPage(), locale: georgian);

    expect(find.bySemanticsLabel('უკან'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Back')), findsNothing);
    semantics.dispose();
  });
}
