import 'package:fuzzzy_seal/lib.dart';

FuzzzySealLocalizations get currentContextLocalization {
  if (navigatorKey.currentContext == null) {
    return FuzzzySealLocalizationsEn();
  }

  return FuzzzySealLocalizations.of(navigatorKey.currentContext!)!;
}
