import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'localization_state.dart';

class LocalizationCubit extends Cubit<LocalizationState>
    with WidgetsBindingObserver {
  LocalizationCubit()
      : super(
          LocalizationState(
            locale: const Locale('ka'),
          ),
        ) {
    WidgetsBinding.instance.addObserver(this);

    loadFromPreferences().then((locale) {
      if (locale != null) {
        changeLocale(locale);
      }
    });
  }

  static const _languageCodeKey = 'language_code';

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);

    if (locales != null && state.followsPhone) {
      final currentLocale = locales.first;
      if (shouldApplyLocale(currentLocale)) {
        changeLocale(currentLocale, isSetByUser: false);
      }
    }
  }

  /// Language: "Like my phone". Forgets the stored choice; the app then
  /// follows the phone's language (English when the phone's is neither).
  Future<void> followPhone() async {
    emit(state.copyWith(followsPhone: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_languageCodeKey);
  }

  bool shouldApplyLocale(Locale locale) {
    return SupportedLocales.supportedLocales
        .any((element) => element.languageCode == locale.languageCode);
  }

  Future<void> changeLocale(
    Locale locale, {
    bool isSetByUser = true,
  }) async {
    if (locale != state.locale || (isSetByUser && state.followsPhone)) {
      emit(
        state.copyWith(
          locale: locale,
          followsPhone: isSetByUser ? false : null,
        ),
      );
    }
    if (isSetByUser) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageCodeKey, locale.languageCode);
    }
  }

  Future<Locale?> loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final langugaeCode = prefs.getString(_languageCodeKey);
    if (langugaeCode != null) {
      return Locale(langugaeCode);
    }
    return null;
  }
}
