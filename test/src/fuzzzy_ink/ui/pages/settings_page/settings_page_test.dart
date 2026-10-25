import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

/// Records every launch instead of opening anything.
class FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launches = <(String, PreferredLaunchMode)>[];
  bool answer = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url, options.mode));
    return answer;
  }
}

void main() {
  late FakeUrlLauncher urlLauncher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.safeRegisterSingleton<PreferencesService>(
      PreferencesService(await SharedPreferences.getInstance()),
    );
    sl.safeRegisterSingleton<CryptoCoreService>(MockCryptoCoreService());
    sl.safeRegisterSingleton<PackageInfo>(
      PackageInfo(
        appName: 'Fuzzzy Ink',
        packageName: 'com.fuzzzycore.ink',
        version: '1.1.0',
        buildNumber: '2',
      ),
    );
    urlLauncher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = urlLauncher;
  });

  tearDown(() async {
    await sl.unregister<PreferencesService>();
    await sl.unregister<CryptoCoreService>();
    await sl.unregister<PackageInfo>();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => LocalizationCubit()),
          BlocProvider(
            create: (_) => FuzzzyCastSettingsCubit(
              preferencesService: sl.get<PreferencesService>(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the file benchmark tile is absent outside the development flavor '
      '(no --flavor here, as in staging and production builds)',
      (tester) async {
    expect(isFileBenchmarkEnabled, isFalse);

    await pumpSettings(tester);

    expect(find.text('Master password'), findsOneWidget);
    expect(find.text('About encryption'), findsOneWidget);
    expect(find.text('Benchmark file encryption (dev)'), findsNothing);
    expect(find.byIcon(Icons.speed), findsNothing);
  });

  testWidgets('shows the legal and support links and the app version',
      (tester) async {
    await pumpSettings(tester);

    expect(find.text('Legal and support'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Deleting your data'), findsOneWidget);
    expect(find.text('Version 1.1.0 (build 2)'), findsOneWidget);
  });

  testWidgets(
      'each link hands the exact fuzzzycore.com page to the system browser',
      (tester) async {
    await pumpSettings(tester);

    for (final title in [
      'Privacy policy',
      'Terms of use',
      'Support',
      'Deleting your data',
    ]) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    expect(urlLauncher.launches, [
      (
        'https://fuzzzycore.com/privacy',
        PreferredLaunchMode.externalApplication
      ),
      ('https://fuzzzycore.com/terms', PreferredLaunchMode.externalApplication),
      (
        'https://fuzzzycore.com/support',
        PreferredLaunchMode.externalApplication
      ),
      (
        'https://fuzzzycore.com/account-deletion',
        PreferredLaunchMode.externalApplication,
      ),
    ]);
  });

  testWidgets('a link no app can open shows a message instead of failing',
      (tester) async {
    urlLauncher.answer = false;
    await pumpSettings(tester);

    await tester.tap(find.text('Privacy policy'));
    await tester.pump();

    expect(find.text('Could not open the link.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
