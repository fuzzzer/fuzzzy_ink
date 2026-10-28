import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

import '../../../../helpers/redesign_harness.dart';
import '../../fuzz_anywhere_fakes.dart';

void main() {
  setUpAll(registerAnywhereFallbacks);

  late AnywhereHarness app;

  setUp(() => app = AnywhereHarness());
  tearDown(() => app.dispose());

  Future<void> pumpSection(WidgetTester tester, {required bool flag}) =>
      pumpRedesign(
        tester,
        BlocProvider.value(
          value: app.settings,
          child: SingleChildScrollView(
            child: FuzzAnywhereSettingsSection(isEnabled: flag),
          ),
        ),
      );

  testWidgets('without the build flag there is no row at all', (tester) async {
    await pumpSection(tester, flag: false);

    expect(find.text('Lock from other apps'), findsNothing);
    expect(find.text('OTHER APPS'), findsNothing);
    expect(find.byKey(const Key('toggle.settings.otherApps')), findsNothing);
  });

  testWidgets('off by default; turning it on shows Lock again, on',
      (tester) async {
    final haptics = recordHaptics(tester);
    await app.settings.load();
    await pumpSection(tester, flag: true);

    expect(find.text('OTHER APPS'), findsOneWidget);
    expect(find.text('Lock from other apps'), findsOneWidget);
    expect(find.text('Experimental'), findsOneWidget);
    expect(find.text('Lock again after each use'), findsNothing);

    await tester.tap(find.byKey(const Key('toggle.settings.otherApps')));
    await tester.pumpAndSettle();

    expect(app.settings.state.settings.isOn, isTrue);
    expect(app.settings.state.settings.locksAgainAfterUse, isTrue);
    expect(find.text('Lock again after each use'), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    // Kept sealed, never in the clear.
    expect(
      app.storage.blobs[FuzzAnywhereLocalDataSource.settingsKey],
      isNotNull,
    );
  });

  testWidgets('"Why?" says what it does and the draft caveat', (tester) async {
    await app.settings.load();
    await pumpSection(tester, flag: true);

    await tester.tap(find.byKey(const Key('why.settings.otherApps')));
    await tester.pumpAndSettle();

    expect(find.text('Locking from other apps'), findsOneWidget);
    expect(
      find.textContaining('may already be saved or synced there'),
      findsOneWidget,
    );
    expect(find.textContaining('shows only in Fuzzzy Ink'), findsOneWidget);
  });

  testWidgets('not read yet: the switch waits', (tester) async {
    await pumpSection(tester, flag: true);

    await tester.tap(find.byKey(const Key('toggle.settings.otherApps')));
    await tester.pumpAndSettle();
    expect(app.settings.state.settings.isOn, isFalse);
  });
}
