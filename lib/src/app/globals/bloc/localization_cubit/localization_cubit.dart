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

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);

    if (locales != null) {
      final currentLocale = locales.first;
      if (shouldApplyLocale(currentLocale)) {
        changeLocale(currentLocale, isSetByUser: false);
      }
    }
  }

  bool shouldApplyLocale(Locale locale) {
    return SupportedLocales.supportedLocales
        .any((element) => element.languageCode == locale.languageCode);
  }

  Future<void> changeLocale(
    Locale locale, {
    bool isSetByUser = true,
  }) async {
    if (locale != state.locale) {
      emit(
        state.copyWith(
          locale: locale,
        ),
      );
    }
    if (isSetByUser) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', locale.languageCode);
    }
  }

  Future<Locale?> loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final langugaeCode = prefs.getString('language_code');
    if (langugaeCode != null) {
      return Locale(langugaeCode);
    }
    return null;
  }
}
