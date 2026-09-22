import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';

extension BuildContextExtension on BuildContext {
  FuzzzyInkLocalizations get fuzzzyInkLocalizations =>
      FuzzzyInkLocalizations.of(this)!;
}
