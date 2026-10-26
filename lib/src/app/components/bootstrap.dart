import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  /// Names the change only, never the states' contents: a state may hold
  /// opened text, a password or a recovery key, and development and profile
  /// builds print this log (security review 2026-10-26).
  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    log(
      'onChange(${bloc.runtimeType}, '
      '${change.currentState.runtimeType} → ${change.nextState.runtimeType})',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  // The app never fetches anything: fuzzzy_ui_kit's fonts are bundled under
  // assets/fonts/ and google_fonts must not fall back to the network.
  GoogleFonts.config.allowRuntimeFetching = false;

  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();

  //TODO Add cross-flavor configuration here

  runApp(await builder());
}
