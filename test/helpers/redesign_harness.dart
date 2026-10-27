import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Both looks the redesign ships: paper (light) and night (dark).
const redesignSkins = [FuzzzySkin.paper, FuzzzySkin.night];

/// Hosts a redesign widget the way the app does: the kit theme in [skin],
/// both languages' delegates, the phone's reduce-motion setting
/// ([reduceMotion]), a text size ([textScale]) and the Fuzzzy Cast switch
/// ([castOn]). [private] puts it below a [SensitiveScreen].
Future<void> pumpRedesign(
  WidgetTester tester,
  Widget child, {
  FuzzzySkin skin = FuzzzySkin.night,
  bool reduceMotion = false,
  bool castOn = false,
  bool private = false,
  double textScale = 1,
  Locale locale = const Locale('en'),
  Size? surface,
}) async {
  SharedPreferences.setMockInitialValues({'fuzzzy_cast_enabled': castOn});
  final preferences = PreferencesService(await SharedPreferences.getInstance());
  if (surface != null) {
    tester.view.physicalSize = surface * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Widget body = child;
  if (private) body = SensitiveScreen(child: body);

  await tester.pumpWidget(
    BlocProvider(
      create: (_) => FuzzzyCastSettingsCubit(preferencesService: preferences),
      child: MaterialApp(
        theme: FuzzzyTheme.build(inkPack, skin),
        locale: locale,
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: app!,
        ),
        home: Scaffold(body: body),
      ),
    ),
  );
}

/// Records the haptics sent to the platform ("HapticFeedbackType.lightImpact"
/// and so on) while [InkHaptics] runs its phone path.
List<String> recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  InkHaptics.debugIsPhone = true;
  addTearDown(() => InkHaptics.debugIsPhone = null);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}
