import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

import '../../../../../helpers/redesign_harness.dart';

void main() {
  group('ActionTile', () {
    testWidgets(
        'the largest text: the big word shrinks to the tile instead of '
        'breaking mid-word', (tester) async {
      await pumpRedesign(
        tester,
        const Row(
          children: [
            Expanded(
              child: ActionTile(
                qaId: 'lock',
                icon: Icons.lock_outline,
                title: 'Lock',
                subtitle: 'For one person',
                inverted: true,
                onTap: null,
              ),
            ),
            Expanded(
              child: ActionTile(
                qaId: 'open',
                icon: Icons.lock_open_outlined,
                title: 'Open',
                subtitle: 'What you got',
                onTap: null,
              ),
            ),
          ],
        ),
        textScale: 3.1,
        surface: const Size(402, 874),
      );
      expect(tester.takeException(), isNull);
      for (final word in ['Lock', 'Open']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(word));
        final lines = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: word.length),
            )
            .map((box) => box.top.round())
            .toSet();
        expect(lines, hasLength(1), reason: '"$word" on one line');
      }
    });

    for (final skin in redesignSkins) {
      for (final reduced in [false, true]) {
        testWidgets('Lock and Open tiles ($skin, reduced motion $reduced)',
            (tester) async {
          var taps = 0;
          await pumpRedesign(
            tester,
            Row(
              children: [
                Expanded(
                  child: ActionTile(
                    qaId: 'lock',
                    icon: Icons.lock_outline,
                    title: 'Lock',
                    subtitle: 'For one person',
                    inverted: true,
                    onTap: () => taps++,
                  ),
                ),
                Expanded(
                  child: ActionTile(
                    qaId: 'open',
                    icon: Icons.lock_open_outlined,
                    title: 'Open',
                    subtitle: 'What you got',
                    onTap: () {},
                  ),
                ),
              ],
            ),
            skin: skin,
            reduceMotion: reduced,
          );
          expect(
            tester.getSize(find.byKey(const Key('tile.lock'))).height,
            greaterThanOrEqualTo(ActionTile.minHeight),
          );
          await tester.tap(find.byKey(const Key('tile.lock')));
          await tester.pumpAndSettle();
          expect(taps, 1);
          expect(
            find.bySemanticsLabel('Lock. For one person'),
            findsOneWidget,
          );
        });
      }
    }

    testWidgets('grows with large Georgian text instead of overflowing',
        (tester) async {
      await pumpRedesign(
        tester,
        Row(
          children: [
            Expanded(
              child: ActionTile(
                qaId: 'lock',
                icon: Icons.lock_outline,
                title: 'ჩაკეტვა',
                subtitle: 'ერთი ადამიანისთვის',
                inverted: true,
                onTap: () {},
              ),
            ),
          ],
        ),
        textScale: 2,
        surface: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PersonRow', () {
    Future<void> pumpRow(
      WidgetTester tester,
      PersonTrust trust, {
      FuzzzySkin skin = FuzzzySkin.night,
      bool reduced = false,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) =>
        pumpRedesign(
          tester,
          PersonRow(
            qaId: 'p1',
            name: 'Tamar',
            trust: trust,
            time: '9:20',
            activity:
                trust == PersonTrust.waiting ? null : 'You locked a message',
            onTap: onTap ?? () {},
            onLongPress: onLongPress,
          ),
          skin: skin,
          reduceMotion: reduced,
        );

    for (final skin in redesignSkins) {
      testWidgets('a waiting person says what happens next ($skin)',
          (tester) async {
        await pumpRow(tester, PersonTrust.waiting, skin: skin);
        expect(find.text('Tamar'), findsOneWidget);
        expect(find.text('T'), findsOneWidget);
        expect(find.byKey(const ValueKey(PersonTrust.waiting)), findsOneWidget);
        expect(find.text('Then you can lock for each other'), findsOneWidget);
        expect(find.text('You locked a message'), findsNothing);
      });

      testWidgets(
          'connected: Checked or Not checked, and the last thing '
          '($skin, reduced motion)', (tester) async {
        await pumpRow(
          tester,
          PersonTrust.notChecked,
          skin: skin,
          reduced: true,
        );
        expect(
          find.byKey(const ValueKey(PersonTrust.notChecked)),
          findsOneWidget,
        );
        expect(find.text('You locked a message'), findsOneWidget);
        await pumpRow(tester, PersonTrust.checked, skin: skin, reduced: true);
        await tester.pump();
        expect(find.byKey(const ValueKey(PersonTrust.checked)), findsOneWidget);
        expect(
          find.byKey(const ValueKey(PersonTrust.notChecked)),
          findsNothing,
        );
      });
    }

    testWidgets('tap opens, long press offers removal', (tester) async {
      var taps = 0;
      var holds = 0;
      await pumpRow(
        tester,
        PersonTrust.checked,
        onTap: () => taps++,
        onLongPress: () => holds++,
      );
      await tester.tap(find.byKey(const Key('person.p1')));
      await tester.longPress(find.byKey(const Key('person.p1')));
      await tester.pumpAndSettle();
      expect((taps, holds), (1, 1));
    });

    testWidgets('a long name ellipsizes on a narrow phone', (tester) async {
      await pumpRedesign(
        tester,
        PersonRow(
          qaId: 'long',
          name: 'A very long name that will not fit on one line at all',
          trust: PersonTrust.waiting,
          onTap: () {},
        ),
        surface: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('HistoryRow', () {
    for (final skin in redesignSkins) {
      for (final reduced in [false, true]) {
        testWidgets(
            'rows say what and when, never the text '
            '($skin, reduced motion $reduced)', (tester) async {
          await pumpRedesign(
            tester,
            Column(
              children: [
                HistoryRow(
                  qaId: 'm1',
                  direction: HistoryDirection.locked,
                  time: '9:20',
                  highlight: true,
                  onTap: () {},
                ),
                HistoryRow(
                  qaId: 'f1',
                  direction: HistoryDirection.opened,
                  time: '8:02',
                  fileName: 'lease-2026.pdf',
                  fileSize: '1.2 MB',
                  onTap: () {},
                ),
              ],
            ),
            skin: skin,
            reduceMotion: reduced,
          );
          expect(find.text('You locked a message'), findsOneWidget);
          expect(find.text('tap to read'), findsOneWidget);
          expect(find.text('You opened lease-2026.pdf'), findsOneWidget);
          expect(find.text('1.2 MB · tap to see'), findsOneWidget);
          expect(
            find.bySemanticsLabel('You locked a message, 9:20'),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('row_tint.active')),
            reduced ? findsNothing : findsOneWidget,
          );
          await tester.pumpAndSettle();
        });
      }
    }

    testWidgets(
        'opened rows show an open padlock, locked rows a closed one '
        '(final regression 2026-10-26)', (tester) async {
      await pumpRedesign(
        tester,
        Column(
          children: [
            HistoryRow(
              qaId: 'locked',
              direction: HistoryDirection.locked,
              time: '9:20',
              onTap: () {},
            ),
            HistoryRow(
              qaId: 'opened',
              direction: HistoryDirection.opened,
              time: '9:21',
              onTap: () {},
            ),
          ],
        ),
      );
      Finder iconIn(String qaId, IconData icon) => find.descendant(
            of: find.byKey(Key('history.$qaId')),
            matching: find.byIcon(icon),
          );
      expect(iconIn('locked', Icons.lock_outline), findsOneWidget);
      expect(iconIn('opened', CupertinoIcons.lock_open), findsOneWidget);
      expect(iconIn('opened', Icons.lock_outline), findsNothing);
    });
  });

  group('FileCard and LockedTextPreview', () {
    for (final skin in redesignSkins) {
      testWidgets('a locked file and a faded locked text ($skin)',
          (tester) async {
        await pumpRedesign(
          tester,
          Column(
            children: [
              const FileCard(
                qaId: 'f',
                name: 'a-very-long-holiday-photo-from-tbilisi-2026.jpg.fuzz',
                size: '3.1 MB',
                state: FileCardState.locked,
              ),
              const FileCard(
                qaId: 's',
                name: 'passport.pdf',
                state: FileCardState.keptInSafe,
              ),
              LockedTextPreview(
                qaId: 'p',
                showLabel: true,
                lockedText: 'Fuzz/${'AQK3x9Tq7vLmZr2pW8cY' * 20}',
              ),
            ],
          ),
          skin: skin,
          surface: const Size(360, 700),
        );
        expect(find.text('3.1 MB · Locked'), findsOneWidget);
        expect(find.text('Kept locked in My safe'), findsOneWidget);
        expect(
          find.text('a-very-long-ho…-2026.jpg.fuzz'),
          findsOneWidget,
          reason: 'the ending stays visible',
        );
        expect(find.text('LOCKED VERSION · SAFE TO SEND'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('locked_preview.p'))).height,
          lessThanOrEqualTo(LockedTextPreview.maxHeight),
        );
        expect(find.byType(SelectableText), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('WaitNotes', () {
    for (final skin in redesignSkins) {
      testWidgets('the two notes, How? opens "Safe to send anywhere" ($skin)',
          (tester) async {
        await pumpRedesign(
          tester,
          const WaitNotes(name: 'Mom', qaId: 'mom'),
          skin: skin,
          reduceMotion: skin == FuzzzySkin.paper,
        );
        expect(
          find.text('Once Mom replies, you can lock messages for each other.'),
          findsOneWidget,
        );
        expect(
          find.text('Send the invite any way, even publicly. It stays safe.'),
          findsOneWidget,
        );
        await tester.tap(find.text('How?'));
        await tester.pumpAndSettle();
        expect(find.text('Safe to send anywhere'), findsOneWidget);
        expect(find.text('Only their reply connects you two.'), findsOneWidget);
      });
    }
  });

  group('SafetyNumberGrid', () {
    const digits =
        '371928046155203149786203590817435267109428650051398647231908';

    test('splits 60 digits into 12 groups of 5', () {
      final groups = SafetyNumberGrid.groupsOf(digits);
      expect(groups, hasLength(12));
      expect(groups.first, '37192');
      expect(groups.last, '31908');
    });

    for (final skin in redesignSkins) {
      testWidgets('three columns, two at large text sizes ($skin)',
          (tester) async {
        await pumpRedesign(
          tester,
          SafetyNumberGrid(
            qaId: 'nino',
            groups: SafetyNumberGrid.groupsOf(digits),
          ),
          skin: skin,
        );
        expect(find.text('37192'), findsOneWidget);
        expect(find.byType(Row), findsNWidgets(4));

        await pumpRedesign(
          tester,
          SafetyNumberGrid(
            qaId: 'nino',
            groups: SafetyNumberGrid.groupsOf(digits),
          ),
          skin: skin,
          textScale: 2,
        );
        expect(find.byType(Row), findsNWidgets(6));
        expect(find.bySemanticsLabel(RegExp('Safety numbers')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
