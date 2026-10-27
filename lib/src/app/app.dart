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

// One page transition for every full-screen screen, on both looks.
final ThemeData _paperTheme = FuzzzyTheme.build().copyWith(
  pageTransitionsTheme: InkPageTransitionsBuilder.theme,
);
final ThemeData _nightTheme = FuzzzyTheme.build(inkPack, FuzzzySkin.night)
    .copyWith(pageTransitionsTheme: InkPageTransitionsBuilder.theme);

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
                  builder: (context, child) {
                    final brightness =
                        switch (look.chosenBrightness.themeMode) {
                      ThemeMode.dark => Brightness.dark,
                      ThemeMode.light => Brightness.light,
                      ThemeMode.system =>
                        MediaQuery.platformBrightnessOf(context),
                    };
                    final theme = brightness == Brightness.dark
                        ? _nightTheme
                        : _paperTheme;
                    return AppSwitcherCover(
                      ground: theme.extension<FuzzzyColors>()!.ground,
                      brightness: brightness,
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
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
