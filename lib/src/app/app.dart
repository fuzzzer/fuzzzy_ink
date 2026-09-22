import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

export 'app_router.dart';
export 'components/components.dart';
export 'globals/globals.dart';
export 'initializer.dart';
export 'ui/ui.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        child: FuzzyLinkListener(
          child: MaterialApp.router(
            scaffoldMessengerKey: scaffoldMessengerKey,
            theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
            localizationsDelegates:
                FuzzzySealLocalizations.localizationsDelegates,
            supportedLocales: FuzzzySealLocalizations.supportedLocales,
            routerConfig: AppRouter.router(
              navigatorKey: navigatorKey,
              scaffoldMessengerKey: scaffoldMessengerKey,
            ),
          ),
        ),
      ),
    );
  }
}
