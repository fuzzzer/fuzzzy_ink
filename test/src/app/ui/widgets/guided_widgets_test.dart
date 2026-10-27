import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

import '../../../../helpers/redesign_harness.dart';

void main() {
  group('InkMark', () {
    for (final skin in redesignSkins) {
      testWidgets(
          'one square mark at the asked size, read as the app '
          '($skin)', (tester) async {
        await pumpRedesign(
          tester,
          const Center(child: InkMark(size: 56, qaId: 'lock')),
          skin: skin,
        );
        expect(
          tester.getSize(find.byKey(const Key('mark.lock'))),
          const Size.square(56),
        );
        expect(find.bySemanticsLabel('Fuzzzy Ink'), findsOneWidget);
      });
    }

    testWidgets('paints the night mark on the dark look', (tester) async {
      await pumpRedesign(
        tester,
        const Center(child: InkMark(size: 56)),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/logo/ink_mark.png',
      );
    });

    testWidgets('paints the paper mark on the light look', (tester) async {
      await pumpRedesign(
        tester,
        const Center(child: InkMark(size: 56)),
        skin: FuzzzySkin.paper,
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/logo/ink_mark_paper.png',
      );
    });
  });

  group('StepsIndicator', () {
    for (final skin in redesignSkins) {
      testWidgets('shows the step and reads it as one phrase ($skin)',
          (tester) async {
        await pumpRedesign(
          tester,
          const StepsIndicator(step: 2, total: 3, label: 'Recovery key'),
          skin: skin,
        );
        expect(find.text('STEP 2 OF 3 · RECOVERY KEY'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Step 2 of 3 · Recovery key'),
          findsOneWidget,
        );
      });
    }
  });

  group('StepPicture', () {
    Widget picture({int done = 0, int? justDone}) => Builder(
          builder: (context) => StepPicture(
            qaId: 'invite',
            steps: StepPicture.inviteSteps(context, name: 'Tamar'),
            done: done,
            justDone: justDone,
          ),
        );

    for (final skin in redesignSkins) {
      for (final reduced in [false, true]) {
        testWidgets(
            'the step just reached fills and its check draws '
            '($skin, reduced motion $reduced)', (tester) async {
          await pumpRedesign(
            tester,
            picture(done: 1, justDone: 0),
            skin: skin,
            reduceMotion: reduced,
          );
          expect(find.text('Invite sent'), findsOneWidget);
          expect(find.text('Tamar replies'), findsOneWidget);
          expect(find.byType(CheckDraw), findsOneWidget);
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel(
              'Done: Invite sent. Next: Tamar replies. '
              'Next: Lock for each other',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('stacks vertically at large text sizes', (tester) async {
      await pumpRedesign(tester, picture(), textScale: 2);
      expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a 320 px phone in Georgian', (tester) async {
      await pumpRedesign(
        tester,
        picture(done: 2),
        locale: const Locale('ka'),
        surface: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('WhyLink and the Why? sheets', () {
    for (final topic in InkInfoTopic.values) {
      testWidgets('"${topic.name}" opens its sheet; Got it closes it',
          (tester) async {
        await pumpRedesign(tester, Center(child: WhyLink(topic: topic)));
        expect(find.text('Why?'), findsOneWidget);

        await tester.tap(find.text('Why?'));
        await tester.pumpAndSettle();
        final l = FuzzzyInkLocalizations.of(
          tester.element(find.byType(InkInfoSheetBody)),
        )!;
        expect(find.text(topic.title(l)), findsOneWidget);
        for (final line in topic.lines(l)) {
          expect(find.text(line), findsOneWidget);
        }
        expect(
          find.byType(StepPicture),
          topic.showsInviteSteps ? findsOneWidget : findsNothing,
        );

        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(find.byType(InkInfoSheetBody), findsNothing);
      });
    }

    testWidgets('a 48 px touch area, read as a button that explains',
        (tester) async {
      await pumpRedesign(
        tester,
        const Center(
          child: WhyLink(
            topic: InkInfoTopic.safeAnywhere,
            label: WhyLinkLabel.how,
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('why.safeAnywhere'))).height,
        greaterThanOrEqualTo(WhyLink.touchHeight),
      );
      final node =
          tester.getSemantics(find.byKey(const Key('why.safeAnywhere')));
      expect(node.label, 'How?');
      expect(node.hint, 'Opens an explanation');
    });

    for (final skin in redesignSkins) {
      testWidgets('both looks, reduced motion ($skin)', (tester) async {
        await pumpRedesign(
          tester,
          const Center(child: WhyLink(topic: InkInfoTopic.safeAnywhere)),
          skin: skin,
          reduceMotion: true,
        );
        await tester.tap(find.text('Why?'));
        await tester.pumpAndSettle();
        expect(find.text('Safe to send anywhere'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('TipLine and KeyTag', () {
    for (final skin in redesignSkins) {
      testWidgets('a tip with its Why? link, and the key tag ($skin)',
          (tester) async {
        await pumpRedesign(
          tester,
          const Column(
            children: [
              TipLine(
                qaId: 'noKey',
                icon: Icons.warning_amber,
                text: 'No key? Then nothing can open it.',
                trailing: WhyLink(topic: InkInfoTopic.noReset),
              ),
              KeyTag(qaId: 'key'),
              KeyTag(label: 'No copy', qaId: 'opened'),
            ],
          ),
          skin: skin,
          surface: const Size(320, 640),
        );
        expect(find.text('No key? Then nothing can open it.'), findsOneWidget);
        expect(find.text('Why?'), findsOneWidget);
        expect(find.text('NO COPY · NO SCREENSHOTS'), findsOneWidget);
        expect(find.text('NO COPY'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Georgian has no capitals: the tag reads as written',
        (tester) async {
      await pumpRedesign(
        tester,
        const KeyTag(),
        locale: const Locale('ka'),
      );
      expect(
        find.text('კოპირება და ეკრანის ანაბეჭდი გამორთულია'),
        findsOneWidget,
      );
    });
  });
}
