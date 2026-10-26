import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

import '../../../../helpers/access_harness.dart';

/// The access screens' own pieces: the strength meter, the password field,
/// the note and the print sheet.
void main() {
  late AccessHarness harness;
  final l10n = FuzzzyInkLocalizationsEn();

  setUp(() async {
    harness = AccessHarness();
    await harness.setUp();
  });

  tearDown(() => harness.tearDown());

  testWidgets('the meter: a tip while empty, then the level in words',
      (tester) async {
    await pumpRedesign(tester, const PasswordMeter(password: ''));
    expect(find.text(l10n.accessStrengthHintEmpty), findsOneWidget);

    await pumpRedesign(tester, const PasswordMeter(password: 'abc'));
    expect(find.text(l10n.accessStrengthWeak), findsOneWidget);
    expect(find.text(l10n.accessStrengthHintWeak), findsOneWidget);

    await pumpRedesign(
      tester,
      const PasswordMeter(password: 'quiet lantern river 58!'),
    );
    expect(find.text(l10n.accessStrengthStrong), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('meter.password'))).label,
      l10n.accessStrengthLabel(l10n.accessStrengthStrong),
    );
  });

  testWidgets('the password field hides, shows, and waits when disabled',
      (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);
    await pumpRedesign(
      tester,
      InkPasswordField(controller: controller, label: 'Password', qaId: 'pw'),
      private: true,
    );
    EditableText editable() => tester.widget(kitField('pw'));
    expect(editable().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('iconbtn.pw.peek')));
    await tester.pump();
    expect(editable().obscureText, isFalse);
    expect(find.byType(NoPlaintextCopy), findsWidgets);

    await pumpRedesign(
      tester,
      InkPasswordField(
        controller: controller,
        label: 'Password',
        enabled: false,
        qaId: 'pw',
      ),
    );
    expect(
      find.ancestor(of: kitField('pw'), matching: find.byType(ExcludeFocus)),
      findsWidgets,
    );
  });

  for (final skin in redesignSkins) {
    testWidgets('the print sheet is paper in the ${skin.name} look',
        (tester) async {
      await pumpRedesign(
        tester,
        SingleChildScrollView(
          child: RecoveryKeyPrintSheet(
            recoveryKey: 'AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZ',
            madeOn: DateTime(2026, 10, 26),
          ),
        ),
        skin: skin,
        private: true,
      );
      final paper = FuzzzyTheme.build().extension<FuzzzyColors>()!;
      final box = tester.widget<Container>(
        find.byKey(const Key('recovery_key.print_sheet')),
      );
      expect((box.decoration! as BoxDecoration).color, paper.surface);
      expect(find.textContaining('October 26, 2026'), findsOneWidget);
      expect(find.text('AAAQ EAYE AUDA OCAJ'), findsOneWidget);
      // On paper the "No copy" tag is not printed.
      expect(find.byType(KeyTag), findsNothing);
    });
  }

  forEveryLook('a note with a bold lead and a Why link fits', (
    tester,
    skin,
    reduceMotion,
    textScale,
  ) async {
    await pumpRedesign(
      tester,
      AccessNote(
        tone: AccessNoteTone.danger,
        bold: l10n.accessNoResetBold,
        text: l10n.accessNoResetLine,
        trailing: const WhyLink(topic: InkInfoTopic.noReset),
      ),
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
      surface: const Size(320, 600),
    );
    expect(find.textContaining(l10n.accessNoResetBold), findsOneWidget);
    expect(find.byKey(const Key('why.noReset')), findsOneWidget);
  });
}
