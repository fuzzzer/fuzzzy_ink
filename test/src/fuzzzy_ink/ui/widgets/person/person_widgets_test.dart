import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

import '../../../../../helpers/people_harness.dart';
import '../../../../../helpers/redesign_harness.dart';

class _MockArchiveExportCubit extends MockCubit<ChatArchiveExportState>
    implements ChatArchiveExportCubit {}

void main() {
  group('sealedTextOf', () {
    test('takes the Fuzz/ text, or the blob inside a link of the right kind',
        () {
      expect(
        sealedTextOf('  Fuzz/abc ', SealedTextKind.acceptance),
        'Fuzz/abc',
      );
      final link = FuzzyLinkGenerator.generateAcceptanceLink('Fuzz/abc')!;
      expect(sealedTextOf(link, SealedTextKind.acceptance), 'Fuzz/abc');
      final invite = FuzzyLinkGenerator.generateInvitationLink('Fuzz/abc')!;
      expect(sealedTextOf(invite, SealedTextKind.invitation), 'Fuzz/abc');
    });

    test('anything else is not an invite or reply', () {
      expect(sealedTextOf('', SealedTextKind.acceptance), isNull);
      expect(sealedTextOf('hello', SealedTextKind.acceptance), isNull);
      final invite = FuzzyLinkGenerator.generateInvitationLink('Fuzz/abc')!;
      expect(sealedTextOf(invite, SealedTextKind.acceptance), isNull);
    });
  });

  group('HistoryFormat', () {
    test('sizes', () {
      expect(HistoryFormat.fileSize(812), '812 B');
      expect(HistoryFormat.fileSize(3250000), '3.1 MB');
      expect(HistoryFormat.fileSize(3 * 1024), '3.0 KB');
    });

    testWidgets('days: Today, Yesterday, then the date', (tester) async {
      HistoryFormat.now = () => DateTime(2026, 10, 26, 12);
      addTearDown(() => HistoryFormat.now = DateTime.now);
      late BuildContext context;
      await pumpRedesign(
        tester,
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      expect(
        HistoryFormat.dayLabel(context, DateTime(2026, 10, 26, 1)),
        'Today',
      );
      expect(
        HistoryFormat.dayLabel(context, DateTime(2026, 10, 25, 23)),
        'Yesterday',
      );
      expect(
        HistoryFormat.dayLabel(context, DateTime(2026, 10, 20)),
        'Tue, Oct 20',
      );
    });
  });

  group('InkNotice', () {
    for (final skin in redesignSkins) {
      testWidgets(
          'a bold lead, the rest, an icon; a chevron when tappable '
          '($skin)', (tester) async {
        var taps = 0;
        await pumpRedesign(
          tester,
          InkNotice(
            kind: InkNoticeKind.warning,
            lead: 'Not checked yet.',
            text: 'Check numbers.',
            onTap: () => taps++,
            qaId: 'test',
          ),
          skin: skin,
        );
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expect(
          find.bySemanticsLabel('Not checked yet. Check numbers.'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('notice.test')));
        expect(taps, 1);
      });
    }
  });

  group('Save history as a file', () {
    late _MockArchiveExportCubit cubit;

    setUp(() {
      sl.safeRegisterSingleton<PasswordStrengthService>(
        PasswordStrengthService(),
      );
      cubit = _MockArchiveExportCubit();
      whenListen(
        cubit,
        const Stream<ChatArchiveExportState>.empty(),
        initialState: const ChatArchiveExportState(),
      );
    });

    tearDown(() => sl.unregister<PasswordStrengthService>());

    FuzzzyButton saveButton(WidgetTester tester) => tester.widget(
          find
              .ancestor(
                of: find.byKey(const Key('btn.exportHistory.save')),
                matching: find.byType(FuzzzyButton),
              )
              .first,
        );

    for (final skin in redesignSkins) {
      testWidgets(
          'one file, locked with a password that must reach Good, with the '
          'strength hint; the sheet is private ($skin)', (tester) async {
        await pumpRedesign(
          tester,
          Builder(
            builder: (context) => FuzzzyButton(
              label: 'open',
              onPressed: () => showHistoryExportSheet(
                context,
                chat: personChat(),
                cubit: cubit,
              ),
            ),
          ),
          skin: skin,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text("Save Nino's history"), findsOneWidget);
        expect(
          find.text('One file, locked with this password.'),
          findsOneWidget,
        );
        expect(find.text('Tip: a few random words.'), findsOneWidget);
        expect(find.byType(SensitiveScreen), findsOneWidget);
        expect(saveButton(tester).onPressed, isNull);

        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pump();
        expect(find.text('Make it longer.'), findsOneWidget);
        expect(saveButton(tester).onPressed, isNull);

        await tester.enterText(
          find.byType(TextField),
          'velvet harbour lantern quietly 42!',
        );
        await tester.pump();
        expect(saveButton(tester).onPressed, isNotNull);
      });
    }
  });
}
