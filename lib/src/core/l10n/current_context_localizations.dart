import 'package:fuzzzy_ink/lib.dart';

FuzzzyInkLocalizations get currentContextLocalization {
  if (navigatorKey.currentContext == null) {
    return FuzzzyInkLocalizationsEn();
  }

  return FuzzzyInkLocalizations.of(navigatorKey.currentContext!)!;
}
