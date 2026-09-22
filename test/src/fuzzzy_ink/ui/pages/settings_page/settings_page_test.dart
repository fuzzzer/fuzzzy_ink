import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.safeRegisterSingleton<PreferencesService>(
      PreferencesService(await SharedPreferences.getInstance()),
    );
    sl.safeRegisterSingleton<CryptoCoreService>(MockCryptoCoreService());
  });

  tearDown(() async {
    await sl.unregister<PreferencesService>();
    await sl.unregister<CryptoCoreService>();
  });

  testWidgets(
      'the file benchmark tile is absent outside the development flavor '
      '(no --flavor here, as in staging and production builds)',
      (tester) async {
    expect(isFileBenchmarkEnabled, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat Authentication'), findsOneWidget);
    expect(find.text('About encryption'), findsOneWidget);
    expect(find.text('Benchmark file encryption (dev)'), findsNothing);
    expect(find.byIcon(Icons.speed), findsNothing);
  });
}
