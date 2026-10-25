import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

export 'app_router.dart';
export 'components/components.dart';
export 'globals/globals.dart';
export 'initializer.dart';
export 'ui/ui.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final ThemeData _paperTheme = FuzzzyTheme.build();
final ThemeData _nightTheme = FuzzzyTheme.build(inkPack, FuzzzySkin.night);

class App extends StatelessWidget {
  const App({super.key});

  static Future<Widget> runner() async {
    await Initializer.preAppInit();

    return const App();
  }

  @override
  Widget build(BuildContext context) {
    return GlobalBlocProviders(
      child: GlobalBlocListeners(
        child: AppAutoLock(
          child: FuzzyLinkListener(
            // Look and Language from Settings (each "Like my phone" until
            // the person picks).
            child: BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, look) =>
                  BlocBuilder<LocalizationCubit, LocalizationState>(
                builder: (context, language) => MaterialApp.router(
                  scaffoldMessengerKey: scaffoldMessengerKey,
                  theme: _paperTheme,
                  darkTheme: _nightTheme,
                  themeMode: look.chosenBrightness.themeMode,
                  locale: language.followsPhone ? null : language.locale,
                  localizationsDelegates:
                      FuzzzyInkLocalizations.localizationsDelegates,
                  supportedLocales: FuzzzyInkLocalizations.supportedLocales,
                  routerConfig: AppRouter.router(
                    navigatorKey: navigatorKey,
                    scaffoldMessengerKey: scaffoldMessengerKey,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
